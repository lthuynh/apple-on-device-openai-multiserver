//
//  ContentView.swift
//  AppleOnDeviceOpenAI
//

import SwiftUI
import Combine

// MARK: - MultiServer ViewModel
@MainActor
class MultiServerViewModel: ObservableObject {
    @Published var serverViewModels: [ServerMode: ServerViewModel] = [:]

    init() {
        for mode in ServerMode.allCases {
            let config = ServerConfiguration(
                host: "127.0.0.1",
                port: mode.defaultPort,
                mode: mode
            )
            serverViewModels[mode] = ServerViewModel(configuration: config)
        }
    }
}

// MARK: - Main View
struct ContentView: View {
    @StateObject private var multiServerVM = MultiServerViewModel()
    @State private var isStarting: [ServerMode: Bool] = [:]
    @State private var isStopping: [ServerMode: Bool] = [:]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)
                    Text("Apple On-Device OpenAI API (MultiServer)")
                        .font(.title)
                        .fontWeight(.semibold)
                    Text("Local Apple Intelligence — Multi-endpoint OpenAI-compatible bridge")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // One panel per endpoint
                ForEach(ServerMode.allCases, id: \.self) { mode in
                    let viewModel = multiServerVM.serverViewModels[mode]!
                    ServerPanel(
                        viewModel: viewModel,
                        isStarting: isStarting[mode] ?? false,
                        isStopping: isStopping[mode] ?? false,
                        onStart: {
                            isStarting[mode] = true
                            Task {
                                await viewModel.startServer()
                                isStarting[mode] = false
                            }
                        },
                        onStop: {
                            isStopping[mode] = true
                            Task {
                                await viewModel.stopServer()
                                isStopping[mode] = false
                            }
                        }
                    )
                }
            }
            .padding()
        }
        .frame(maxWidth: 650)
    }
}

// MARK: - Server Panel View
struct ServerPanel: View {
    @ObservedObject var viewModel: ServerViewModel
    var isStarting: Bool
    var isStopping: Bool
    var onStart: () -> Void
    var onStop: () -> Void

    var body: some View {
        GroupBox(viewModel.configuration.mode.displayName) {
            VStack(spacing: 12) {
                // Status Row
                HStack {
                    Circle()
                        .fill(viewModel.isRunning ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    Text(viewModel.isRunning ? "Running" : "Stopped")
                        .font(.headline)
                        .foregroundColor(viewModel.isRunning ? .green : .red)
                    Spacer()
                    Text(viewModel.configuration.mode.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Model Availability
                HStack {
                    Text("Apple Intelligence:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if viewModel.isCheckingModel {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Checking...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Circle()
                            .fill(viewModel.isModelAvailable ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(viewModel.isModelAvailable ? "Available" : "Not Available")
                            .font(.subheadline)
                            .foregroundColor(viewModel.isModelAvailable ? .green : .orange)
                    }
                    Spacer()
                    if !viewModel.isModelAvailable && !viewModel.isCheckingModel {
                        Button("Retry") {
                            Task { await viewModel.checkModelAvailability() }
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                }

                if let reason = viewModel.modelUnavailableReason, !viewModel.isModelAvailable {
                    Text(reason)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.vertical, 2)
                }

                if let error = viewModel.lastError {
                    Text("Error: \(error)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.vertical, 2)
                }

                // Start/Stop controls
                HStack {
                    if viewModel.isRunning {
                        Button("Stop Server", action: onStop)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(isStopping)
                            .tint(.red)
                    } else {
                        Button(
                            viewModel.isModelAvailable ? "Start Server" : "Model Not Available",
                            action: onStart
                        )
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(isStarting || !viewModel.isModelAvailable || viewModel.isCheckingModel)
                        .tint(viewModel.isModelAvailable ? .green : .gray)
                    }
                    if isStarting || isStopping {
                        ProgressView().scaleEffect(0.8)
                    }
                }

                // Show endpoints if running
                if viewModel.isRunning {
                    GroupBox("Endpoints") {
                        VStack(alignment: .leading, spacing: 8) {
                            APIEndpointRow(
                                title: "Base URL",
                                subtitle: "OpenAI clients",
                                url: viewModel.openaiBaseURL,
                                onCopy: { viewModel.copyToClipboard(viewModel.openaiBaseURL) }
                            )
                            APIEndpointRow(
                                title: "Chat Completions",
                                subtitle: "POST endpoint",
                                url: viewModel.chatCompletionsEndpoint,
                                onCopy: { viewModel.copyToClipboard(viewModel.chatCompletionsEndpoint) }
                            )
                        }
                    }
                }

                // Quick start if running
                if viewModel.isRunning {
                    GroupBox("Quick Start") {
                        let pythonCode = """
                            from openai import OpenAI

                            client = OpenAI(
                                base_url="\(viewModel.openaiBaseURL)",
                                api_key="not-needed"
                            )

                            response = client.chat.completions.create(
                                model="\(viewModel.modelName)",
                                messages=[{"role": "user", "content": "Hello!"}]
                            )
                            """
                        CodeBlock(
                            code: pythonCode,
                            onCopy: { viewModel.copyToClipboard(pythonCode) }
                        )
                    }
                }

                // Config section
                GroupBox("Configuration") {
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
                            TextField("\(viewModel.configuration.port)", text: $viewModel.portInput)
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
            }
            .padding()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Helper Views (APIEndpointRow, CodeBlock, EndpointRow)
struct APIEndpointRow: View {
    let title: String
    let subtitle: String
    let url: String
    let onCopy: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            HStack {
                Text(url)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(1)
                Button("Copy") { onCopy() }
                    .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct CodeBlock: View {
    let code: String
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(code)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                }
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Button("Copy Code") { onCopy() }
                .buttonStyle(.borderless)
                .font(.caption)
        }
    }
}

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
            Text("•").foregroundColor(.secondary)
            Text(description).foregroundColor(.secondary)
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