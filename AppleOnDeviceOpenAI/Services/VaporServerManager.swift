//
//  VaporServerManager.swift
//  AppleOnDeviceOpenAI
//

import Combine
import Foundation
import FoundationModels
import Vapor
import AsyncHTTPClient

enum ServerMode: String, CaseIterable, Identifiable {
    case base, deterministic, creative

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .base: return "apple-fm-base"
        case .deterministic: return "apple-fm-deterministic"
        case .creative: return "apple-fm-creative"
        }
    }
    var defaultPort: Int {
        switch self {
        case .base: return 11535
        case .deterministic: return 11536
        case .creative: return 11537
        }
    }
}

struct ServerConfiguration {
    var host: String
    var port: Int
    var mode: ServerMode

    static let `default` = ServerConfiguration(host: "127.0.0.1", port: 11535, mode: .base)

    var url: String { "http://\(host):\(port)" }
    var openaiBaseURL: String { "\(url)/v1" }
    var chatCompletionsEndpoint: String { "\(url)/v1/chat/completions" }
}

@MainActor
class VaporServerManager: ObservableObject {
    @Published var isRunning = false
    @Published var lastError: String?

    private var app: Application?
    private var serverTask: Task<Void, Never>?

    private var mode: ServerMode = .base
    private static var loggingBootstrapped = false

    func startServer(configuration: ServerConfiguration) async {
        guard !isRunning else { return }

        do {
            self.mode = configuration.mode

            var env = try Environment.detect()
            if !Self.loggingBootstrapped {
                try LoggingSystem.bootstrap(from: &env)
                Self.loggingBootstrapped = true
            }

            // Vapor 5/Swift 6: use Application.make instead of Application(env)
            let app = try await Application.make(env, .singleton)
            self.app = app
            app.environment.arguments = [app.environment.arguments[0]]

            configureRoutes(app, mode: mode)

            app.http.server.configuration.hostname = configuration.host
            app.http.server.configuration.port = configuration.port

            serverTask = Task {
                do {
                    try await app.execute()
                } catch {
                    await MainActor.run {
                        self.lastError = error.localizedDescription
                        self.isRunning = false
                    }
                }
            }

            isRunning = true
            lastError = nil

        } catch {
            lastError = error.localizedDescription
        }
    }

    func stopServer() async {
        guard isRunning else { return }
        serverTask?.cancel()
        serverTask = nil
        if let app = app {
            try? await app.asyncShutdown()
            self.app = nil
        }
        isRunning = false
    }

    private func configureRoutes(_ app: Application, mode: ServerMode) {
        app.get("health") { req async -> HTTPStatus in .ok }

        app.get("status") { req async throws -> ServerStatus in
            let (available, reason) = await aiManager.isModelAvailable()
            let supportedLanguages = await aiManager.getSupportedLanguages()
            return ServerStatus(
                modelAvailable: available,
                reason: reason ?? "Model is available",
                supportedLanguages: supportedLanguages,
                serverVersion: "1.0.0",
                appleIntelligenceCompatible: true
            )
        }

        let v1 = app.grouped("v1")

        v1.get("models") { req async throws -> ModelsResponse in
            let (available, _) = await aiManager.isModelAvailable()
            var models: [ModelInfo] = []
            if available {
                models.append(ModelInfo(
                    id: mode.displayName,
                    object: "model",
                    created: Int(Date().timeIntervalSince1970),
                    ownedBy: "apple-on-device-openai"))
            }
            return ModelsResponse(object: "list", data: models)
        }

        v1.post("chat", "completions") { [self] req async throws -> Response in
            let chatRequest = try req.content.decode(ChatCompletionRequest.self)
            guard !chatRequest.messages.isEmpty else {
                throw Abort(.badRequest, reason: "No messages provided")
            }

            let temp = chatRequest.temperature ?? 0.7
            let topP = chatRequest.topP ?? 0.95

            func fixedCall(_ temp: Double, _ topP: Double, modelName: String) async throws -> Response {
                let response = try await aiManager.generateResponse(
                    for: chatRequest.messages,
                    temperature: temp,
                    maxTokens: chatRequest.maxTokens
                )
                let chatResponse = ChatCompletionResponse(
                    id: "chatcmpl-\(UUID().uuidString)",
                    object: "chat.completion",
                    created: Int(Date().timeIntervalSince1970),
                    model: modelName,
                    choices: [
                        ChatCompletionChoice(
                            index: 0,
                            message: ChatMessage(role: "assistant", content: response, name: nil),
                            delta: nil,
                            finishReason: "stop"
                        )
                    ]
                )
                let jsonData = try JSONEncoder().encode(chatResponse)
              let res = Response()
                res.headers.contentType = .json
                res.body = .init(data: jsonData)
                return res
            }

            switch mode {
            case .base:
                if temp < 0.2 || topP < 0.2 {
                    return try await self.proxyRequest(toPort: ServerMode.deterministic.defaultPort, with: chatRequest)
                } else if temp >= 0.8 || topP >= 0.8 {
                    return try await self.proxyRequest(toPort: ServerMode.creative.defaultPort, with: chatRequest)
                } else {
                    return try await fixedCall(temp, topP, modelName: mode.displayName)
                }
            case .deterministic:
                return try await fixedCall(0.1, 0.0, modelName: mode.displayName)
            case .creative:
                return try await fixedCall(0.9, 0.9, modelName: mode.displayName)
            }
        }
    }

    // Proxy helper (using async Vapor HTTPClient)
    private func proxyRequest(toPort port: Int, with chatRequest: ChatCompletionRequest) async throws -> Response {
        let client = HTTPClient(eventLoopGroupProvider: .singleton)
        defer { Task { try? await client.shutdown() } }
        let url = "http://127.0.0.1:\(port)/v1/chat/completions"
        var request = try HTTPClient.Request(url: url, method: .POST)
        let jsonData = try JSONEncoder().encode(chatRequest)
        request.body = .data(jsonData)
        let result = try await client.execute(request: request).get()
        let buffer = result.body ?? ByteBuffer()
        let vaporResponse = Response(status: HTTPResponseStatus(statusCode: Int(result.status.code)))
        vaporResponse.body = Response.Body(buffer: buffer)
        for (key, value) in result.headers {
            vaporResponse.headers.replaceOrAdd(name: key, value: value)
        }
        return vaporResponse
    }

    deinit {
        Task { [app] in try? await app?.asyncShutdown() }
    }
}
