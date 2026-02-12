//
//  VoiceInteractionView.swift
//  EchoMineVPModule
//
//  UI for voice interaction with VAD support
//

import SwiftUI

struct VoiceInteractionView: View {
    @StateObject private var client = VoiceInteractionClient()
    @State private var showSettings = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    Text("Voice Interaction")
                        .font(.largeTitle)
                        .bold()
            
            // Connection & Voice Activity Status
            HStack(spacing: 20) {
                // Connection status
                HStack {
                    Circle()
                        .fill(client.isConnected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    
                    Text(client.isConnected ? "Connected" : "Disconnected")
                        .font(.caption)
                        .foregroundColor(client.isConnected ? .green : .red)
                }
                
                // Voice activity indicator
                if client.isRecording {
                    HStack {
                        Circle()
                            .fill(client.isSpeaking ? Color.orange : Color.gray)
                            .frame(width: 12, height: 12)
                            .animation(.easeInOut(duration: 0.3), value: client.isSpeaking)
                        
                        Text(client.isSpeaking ? "Speaking" : "Listening")
                            .font(.caption)
                            .foregroundColor(client.isSpeaking ? .orange : .gray)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            
            // Debug Information
            VStack(alignment: .leading, spacing: 8) {
                Text("🐛 Debug Info")
                    .font(.caption)
                    .bold()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status: \(client.connectionStatus)")
                        .font(.caption2)
                        .monospaced()
                    
                    Text("Server: ws://\(ServerConfig.shared.host):\(ServerConfig.shared.port)/ws/stt")
                        .font(.caption2)
                        .monospaced()
                    
                    if client.isRecording {
                        Text("🎤 Frames sent: \(client.audioFramesSent)")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .monospaced()
                    }
                    
                    if let error = client.errorMessage {
                        Text("Error: \(error)")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .monospaced()
                    }
                    
                    Text(client.lastServerMessage)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .monospaced()
                }
            }
            .padding()
            .background(.yellow.opacity(0.1))
            .cornerRadius(8)
            
            // Your Speech (Transcription)
            VStack(alignment: .leading, spacing: 10) {
                Text("Your Speech:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(client.transcription.isEmpty ? "Speak to see transcription..." : client.transcription)
                    .font(.title3)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                    .background(.blue.opacity(0.1))
                    .cornerRadius(12)
            }
            
            // AI Response (RAG Answer)
            VStack(alignment: .leading, spacing: 10) {
                Text("AI Response:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(client.ragAnswer.isEmpty ? "AI response will appear here..." : client.ragAnswer)
                    .font(.title3)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                    .background(.green.opacity(0.1))
                    .cornerRadius(12)
            }
            
            // Conversation History
            if !client.allConversations.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Conversation History:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Clear") {
                            client.allConversations.removeAll()
                        }
                        .font(.caption)
                    }
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(client.allConversations.enumerated()), id: \.offset) { index, conversation in
                                VStack(alignment: .leading, spacing: 6) {
                                    // Question
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("Q\(index + 1):")
                                            .font(.caption)
                                            .bold()
                                            .foregroundColor(.blue)
                                            .frame(width: 30, alignment: .leading)
                                        
                                        Text(conversation.query)
                                            .font(.body)
                                    }
                                    
                                    // Answer
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("A\(index + 1):")
                                            .font(.caption)
                                            .bold()
                                            .foregroundColor(.green)
                                            .frame(width: 30, alignment: .leading)
                                        
                                        Text(conversation.answer)
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 8)
                                
                                if index < client.allConversations.count - 1 {
                                    Divider()
                                }
                            }
                        }
                        .padding()
                    }
                    .frame(maxHeight: 200)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
            }
            
            // Error Message
            if let error = client.errorMessage {
                Text("⚠️ \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
                    .background(.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Spacer()
            
            // Controls
            VStack(spacing: 15) {
                // Connect/Disconnect
                if !client.isConnected {
                    Button(action: {
                        Task {
                            await client.connect()
                        }
                    }) {
                        Label("Connect to Server", systemImage: "network")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                } else {
                    Button(action: {
                        client.disconnect()
                    }) {
                        Label("Disconnect", systemImage: "network.slash")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                
                // Start/Stop Recording
                if client.isConnected {
                    if !client.isRecording {
                        Button(action: {
                            Task {
                                try? await client.startRecording()
                            }
                        }) {
                            Label("Start Listening", systemImage: "mic.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    } else {
                        Button(action: {
                            client.stopRecording()
                        }) {
                            Label("Stop Listening", systemImage: "mic.slash.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.orange)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                }
                
                // Settings
                Button(action: {
                    showSettings = true
                }) {
                    Label("Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.gray.opacity(0.3))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
        .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: {
                    // Disconnect before closing
                    if client.isConnected {
                        client.disconnect()
                    }
                    dismiss()
                }) {
                    Label("Close", systemImage: "xmark.circle.fill")
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showSettings = true
                }) {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            VoiceSettingsView(client: client)
        }
        }
    }
}

// MARK: - Settings View

struct VoiceSettingsView: View {
    @ObservedObject var client: VoiceInteractionClient
    @Environment(\.dismiss) private var dismiss
    
    // Editable server configuration
    @State private var serverHost: String = ServerConfig.shared.host
    @State private var serverPort: String = String(ServerConfig.shared.port)
    @State private var showSaveAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Server Configuration") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Host IP Address")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextField("192.168.1.64", text: $serverHost)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.numbersAndPunctuation)
                            .monospaced()
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Port")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextField("8001", text: $serverPort)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .monospaced()
                    }
                    
                    LabeledContent("Endpoint", value: "/ws/chat")
                        .font(.caption)
                    
                    // Save button
                    Button(action: saveConfiguration) {
                        Label("Save & Reconnect", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(client.isConnected)
                    
                    if client.isConnected {
                        Text("⚠️ Disconnect first to change settings")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                
                Section("Current Connection") {
                    LabeledContent("Connecting to", value: "ws://\(serverHost):\(serverPort)/ws/chat")
                        .font(.caption)
                        .monospaced()
                }
                
                if let config = client.serverConfig {
                    Section("Server Settings (from server)") {
                        LabeledContent("Sample Rate", value: "\(config.sampleRate) Hz")
                        LabeledContent("Frame Duration", value: "\(config.frameMs) ms")
                        LabeledContent("Frame Size", value: "\(config.frameBytes) bytes")
                        LabeledContent("Silence Cutoff", value: "\(config.silenceCutoffMs) ms")
                    }
                }
                
                Section("Client Audio") {
                    LabeledContent("Sample Rate", value: "16000 Hz")
                    LabeledContent("Frame Duration", value: "20 ms")
                    LabeledContent("Format", value: "PCM16")
                    LabeledContent("Channels", value: "Mono")
                }
                
                Section("Status") {
                    LabeledContent("Connection", value: client.isConnected ? "✅ Connected" : "❌ Disconnected")
                    LabeledContent("Recording", value: client.isRecording ? "🎤 Active" : "⏸️ Inactive")
                    LabeledContent("Voice Activity", value: client.isSpeaking ? "🗣️ Speaking" : "🤐 Silent")
                }
                
                Section("Features") {
                    LabeledContent("VAD", value: "✅ Server-side")
                    LabeledContent("STT Model", value: "Faster-Whisper (tiny)")
                    LabeledContent("LLM", value: "Ollama (nemotron-3-nano)")
                    LabeledContent("RAG", value: "✅ LangChain + ChromaDB")
                    LabeledContent("Memory", value: "✅ Auto-save important talks")
                    LabeledContent("Language", value: "English")
                }
                
                Section("Quick Presets") {
                    Button("📱 iPhone Hotspot (172.20.10.3)") {
                        serverHost = "172.20.10.3"
                        serverPort = "8001"
                    }
                    
                    Button("🏠 Local Network (192.168.1.x)") {
                        serverHost = "192.168.1.64"
                        serverPort = "8001"
                    }
                    
                    Button("💻 Localhost (127.0.0.1)") {
                        serverHost = "127.0.0.1"
                        serverPort = "8001"
                    }
                }
            }
            .navigationTitle("Voice Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Configuration", isPresented: $showSaveAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func saveConfiguration() {
        // Validate port
        guard let port = Int(serverPort), port > 0, port < 65536 else {
            alertMessage = "Invalid port number. Must be between 1-65535."
            showSaveAlert = true
            return
        }
        
        // Validate host (basic check)
        let trimmedHost = serverHost.trimmingCharacters(in: .whitespaces)
        guard !trimmedHost.isEmpty else {
            alertMessage = "Host cannot be empty."
            showSaveAlert = true
            return
        }
        
        // Update ServerConfig with new values
        ServerConfig.shared.update(host: trimmedHost, port: port)
        
        alertMessage = """
        ✅ Configuration saved!
        
        Host: \(trimmedHost)
        Port: \(port)
        URL: ws://\(trimmedHost):\(port)/ws/chat
        
        Tap 'Connect to Server' to apply changes.
        """
        showSaveAlert = true
        
        print("💾 Server configuration updated: \(trimmedHost):\(port)")
    }
}

#Preview {
    VoiceInteractionView()
}
