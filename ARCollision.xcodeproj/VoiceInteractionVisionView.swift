//
//  VoiceInteractionVisionView.swift
//  EchoMineVPModule
//
//  visionOS-optimized voice interaction with spatial design
//

import SwiftUI

struct VoiceInteractionVisionView: View {
    @StateObject private var client = VoiceInteractionClient()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background with subtle glass effect
            Color.clear
                .background(.ultraThinMaterial)
            
            VStack(spacing: 40) {
                // Header with close button
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Voice TestingV3")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                        
                        Text("RAG-powered Voice Interaction")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        client.disconnect()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                
                // Status Ornament
                HStack(spacing: 30) {
                    // Connection status
                    HStack(spacing: 12) {
                        Circle()
                            .fill(client.isConnected ? Color.green : Color.red)
                            .frame(width: 16, height: 16)
                            .shadow(color: client.isConnected ? .green : .red, radius: 8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(client.isConnected ? "Connected" : "Disconnected")
                                .font(.headline)
                                .foregroundColor(client.isConnected ? .green : .red)
                            
                            if let config = client.serverConfig {
                                Text("\(config.sampleRate) Hz • \(config.frameMs)ms")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    // Voice activity indicator
                    if client.isRecording {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(client.isSpeaking ? Color.orange : Color.gray.opacity(0.5))
                                .frame(width: 16, height: 16)
                                .shadow(color: client.isSpeaking ? .orange : .clear, radius: 8)
                                .animation(.easeInOut(duration: 0.3), value: client.isSpeaking)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(client.isSpeaking ? "Speaking..." : "Listening")
                                    .font(.headline)
                                    .foregroundColor(client.isSpeaking ? .orange : .gray)
                                
                                Text(client.isSpeaking ? "VAD Active" : "Awaiting voice")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .shadow(radius: 10)
                
                // Main Content Area
                HStack(spacing: 30) {
                    // Your Speech Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "person.wave.2")
                                .font(.title2)
                                .foregroundStyle(.blue)
                            
                            Text("Your Speech")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Spacer()
                        }
                        
                        ScrollView {
                            Text(client.transcription.isEmpty 
                                ? "Speak to see your transcription appear here..." 
                                : client.transcription)
                                .font(.body)
                                .foregroundStyle(client.transcription.isEmpty ? .secondary : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                        .frame(minHeight: 150)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
                    .glassBackgroundEffect()
                    
                    // AI Response Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "brain.filled.head.profile")
                                .font(.title2)
                                .foregroundStyle(.green)
                            
                            Text("AI Response")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Spacer()
                        }
                        
                        ScrollView {
                            Text(client.ragAnswer.isEmpty 
                                ? "AI response will appear here..." 
                                : client.ragAnswer)
                                .font(.body)
                                .foregroundStyle(client.ragAnswer.isEmpty ? .secondary : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                        .frame(minHeight: 150)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
                    .glassBackgroundEffect()
                }
                .frame(maxHeight: 300)
                
                // Conversation History (if any)
                if !client.allConversations.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Conversation History")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Button("Clear") {
                                client.allConversations.removeAll()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.horizontal)
                        
                        ScrollView {
                            VStack(spacing: 16) {
                                ForEach(Array(client.allConversations.enumerated()), id: \.offset) { index, conversation in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(alignment: .top, spacing: 12) {
                                            Text("Q\(index + 1)")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.blue)
                                                .frame(width: 30)
                                            
                                            Text(conversation.query)
                                                .font(.callout)
                                        }
                                        
                                        HStack(alignment: .top, spacing: 12) {
                                            Text("A\(index + 1)")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.green)
                                                .frame(width: 30)
                                            
                                            Text(conversation.answer)
                                                .font(.callout)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding()
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(maxHeight: 200)
                    }
                    .padding(.vertical)
                }
                
                // Error Display
                if let error = client.errorMessage {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                    .padding()
                    .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.red.opacity(0.3), lineWidth: 1)
                    )
                }
                
                Spacer()
                
                // Control Buttons
                HStack(spacing: 20) {
                    // Connect/Disconnect
                    if !client.isConnected {
                        Button(action: {
                            Task {
                                await client.connect()
                            }
                        }) {
                            Label("Connect to Server", systemImage: "network")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .controlSize(.large)
                    } else {
                        Button(action: {
                            client.disconnect()
                        }) {
                            Label("Disconnect", systemImage: "network.slash")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .controlSize(.large)
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
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .controlSize(.large)
                        } else {
                            Button(action: {
                                client.stopRecording()
                            }) {
                                Label("Stop Listening", systemImage: "mic.slash.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                            .controlSize(.large)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(40)
        }
        .frame(minWidth: 900, minHeight: 700)
    }
}

#Preview {
    VoiceInteractionVisionView()
}
