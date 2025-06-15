//
//  VaporServerManager.swift
//  AppleOnDeviceOpenAI
//
//  Created by Channing Dai on 6/15/25.
//

import Combine
import Foundation
import Vapor

@MainActor
class VaporServerManager: ObservableObject {
    @Published var isRunning = false
    @Published var lastError: String?

    private var app: Application?
    private var serverTask: Task<Void, Never>?

    func startServer(configuration: ServerConfiguration) async {
        guard !isRunning else { return }

        do {
            // Create Vapor application
            var env = try Environment.detect()
            try LoggingSystem.bootstrap(from: &env)

            let app = Application(env)
            self.app = app

            // Fix for running Vapor in iOS/macOS app - clear command line arguments
            app.environment.arguments = [app.environment.arguments[0]]

            // Configure routes
            configureRoutes(app)

            // Configure server
            app.http.server.configuration.hostname = configuration.host
            app.http.server.configuration.port = configuration.port

            // Start server in background task
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

        // Cancel the server task
        serverTask?.cancel()
        serverTask = nil

        // Shutdown the application
        if let app = app {
            try? await app.asyncShutdown()
            self.app = nil
        }

        isRunning = false
    }

    private func configureRoutes(_ app: Application) {
        // Basic health check endpoint
        app.get("health") { req async in
            return "OK"
        }

        // Hello world endpoint
        app.get("hello") { req async in
            return "Hello from Vapor server!"
        }

        // Echo endpoint for testing
        app.post("echo") { req async throws in
            return "Echo received"
        }
    }

    deinit {
        Task { [app] in
            try? await app?.asyncShutdown()
        }
    }
}
