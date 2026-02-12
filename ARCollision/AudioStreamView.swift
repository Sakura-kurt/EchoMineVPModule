//
//  AudioStreamView.swift
//  EchoMineVPModule
//
//  UI for audio streaming and speech-to-text
//

import SwiftUI

struct AudioStreamView: View {
    @StateObject private var client = AudioStreamClient()
    @State private var serverHost: String = "127.0.0.1"
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            Text("Speech to Text")
                .font(.largeTitle)
                .bold()
            
            // Connection Status
            HStack {
                Circle()
                    .fill(client.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                Text(client.isConnected ? "Connected" : "Disconnected")
                    .font(.headline)
                    .foregroundColor(client.isConnected ? .green : .red)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            
            // Transcription Display
            ScrollView {
                Text(client.transcription.isEmpty ? "Transcription will appear here..." : client.transcription)
                    .font(.title3)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            }
            
            // Error Message
            if let error = client.errorMessage {
                Text("⚠️ \(error)")
                    .foregroundColor(.red)
                    .padding()
                    .background(.ultraThinMaterial)
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
                            Label("Start Recording", systemImage: "mic.fill")
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
                            Label("Stop Recording", systemImage: "mic.slash.fill")
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
        .sheet(isPresented: $showSettings) {
            SettingsView(serverHost: $serverHost, client: client)
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Binding var serverHost: String
    let client: AudioStreamClient
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Server Configuration") {
                    TextField("Server Host", text: $serverHost)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .monospaced()
                    
                    Text("Default: 127.0.0.1")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Audio Configuration") {
                    LabeledContent("Sample Rate", value: "16000 Hz")
                    LabeledContent("Frame Duration", value: "20 ms")
                    LabeledContent("Format", value: "PCM16")
                }
                
                Section("Status") {
                    LabeledContent("Connection", value: client.isConnected ? "Connected" : "Disconnected")
                    LabeledContent("Recording", value: client.isRecording ? "Active" : "Inactive")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AudioStreamView()
}
