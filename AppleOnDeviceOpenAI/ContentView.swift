//
//  ContentView.swift
//  AppleOnDeviceOpenAI
//
//  Created by Channing Dai on 6/15/25.
//

import Combine
import SwiftUI

// MARK: - Models
struct ServerConfiguration {
    var host: String
    var port: Int

    static let `default` = ServerConfiguration(
        host: "127.0.0.1",
        port: 11535
    )

    var url: String {
        "http://\(host):\(port)"
    }
}

// MARK: - ViewModel
@MainActor
class ServerViewModel: ObservableObject {
    @Published var configuration = ServerConfiguration.default
    @Published var hostInput: String = "127.0.0.1"
    @Published var portInput: String = "11535"

    private let serverManager = VaporServerManager()

    var isRunning: Bool {
        serverManager.isRunning
    }

    var lastError: String? {
        serverManager.lastError
    }

    var serverURL: String {
        configuration.url
    }

    init() {
        // Initialize with current configuration values
        self.hostInput = configuration.host
        self.portInput = String(configuration.port)
    }

    func startServer() async {
        updateConfiguration()
        await serverManager.startServer(configuration: configuration)
    }

    func stopServer() async {
        await serverManager.stopServer()
    }

    private func updateConfiguration() {
        let trimmedHost = hostInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedHost.isEmpty {
            configuration.host = trimmedHost
        }

        if let port = Int(portInput.trimmingCharacters(in: .whitespacesAndNewlines)),
            port > 0 && port <= 65535
        {
            configuration.port = port
        }
    }

    func resetToDefaults() {
        configuration = ServerConfiguration.default
        hostInput = configuration.host
        portInput = String(configuration.port)
    }
}

// MARK: - Main View
struct ContentView: View {
    @StateObject private var viewModel = ServerViewModel()
    @State private var isStarting = false
    @State private var isStopping = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "server.rack")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)

                Text("Vapor Server Manager")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Start and stop your local Vapor web server")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Server Status
            GroupBox("Server Status") {
                VStack(spacing: 16) {
                    HStack {
                        Circle()
                            .fill(viewModel.isRunning ? Color.green : Color.red)
                            .frame(width: 12, height: 12)

                        Text(viewModel.isRunning ? "Running" : "Stopped")
                            .font(.headline)
                            .foregroundColor(viewModel.isRunning ? .green : .red)

                        Spacer()
                    }

                    if viewModel.isRunning {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Server URL:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack {
                                Text(viewModel.serverURL)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)

                                Spacer()

                                Button("Copy") {
                                    #if os(macOS)
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(
                                            viewModel.serverURL, forType: .string)
                                    #endif
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    if let error = viewModel.lastError {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Error:")
                                .font(.caption)
                                .foregroundColor(.red)

                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.red.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }

                    HStack {
                        if viewModel.isRunning {
                            Button("Stop Server") {
                                Task {
                                    isStopping = true
                                    await viewModel.stopServer()
                                    isStopping = false
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(isStopping)
                            .tint(.red)
                        } else {
                            Button("Start Server") {
                                Task {
                                    isStarting = true
                                    await viewModel.startServer()
                                    isStarting = false
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(isStarting)
                            .tint(.green)
                        }

                        if isStarting || isStopping {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
            }

            // Server Configuration
            GroupBox("Server Configuration") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Host:")
                            .frame(width: 60, alignment: .leading)
                        TextField("127.0.0.1", text: $viewModel.hostInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(viewModel.isRunning)
                    }

                    HStack {
                        Text("Port:")
                            .frame(width: 60, alignment: .leading)
                        TextField("11535", text: $viewModel.portInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(viewModel.isRunning)
                    }

                    HStack {
                        Spacer()
                        Button("Reset to Defaults") {
                            viewModel.resetToDefaults()
                        }
                        .buttonStyle(.borderless)
                        .disabled(viewModel.isRunning)
                    }
                }
            }

            Spacer()

            // Available endpoints
            if viewModel.isRunning {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Available Endpoints:")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 4) {
                        EndpointRow(method: "GET", path: "/health", description: "Health check")
                        EndpointRow(method: "GET", path: "/hello", description: "Hello world")
                        EndpointRow(method: "POST", path: "/echo", description: "Echo request body")
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .frame(maxWidth: 500)
    }
}

// MARK: - Helper Views
struct EndpointRow: View {
    let method: String
    let path: String
    let description: String

    var body: some View {
        HStack {
            Text(method)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(methodColor.opacity(0.2))
                .foregroundColor(methodColor)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(path)
                .font(.system(.body, design: .monospaced))

            Text("•")
                .foregroundColor(.secondary)

            Text(description)
                .foregroundColor(.secondary)

            Spacer()
        }
    }

    private var methodColor: Color {
        switch method {
        case "GET": return .green
        case "POST": return .blue
        case "PUT": return .orange
        case "DELETE": return .red
        default: return .gray
        }
    }
}

#Preview {
    ContentView()
}
