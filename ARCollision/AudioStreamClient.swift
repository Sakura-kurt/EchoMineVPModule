//
//  AudioStreamClient.swift
//  EchoMineVPModule
//
//  Audio streaming client for WebSocket STT
//

import Foundation
import AVFoundation
import Combine

/// Audio streaming client that captures audio and sends it to a WebSocket server for speech-to-text
@MainActor
class AudioStreamClient: NSObject, ObservableObject {
    
    // MARK: - Configuration
    
    private let sampleRate: Double = 16000
    private let frameMs: Double = 20
    private var samplesPerFrame: Int {
        Int(sampleRate * frameMs / 1000)
    }
    
    // MARK: - State
    
    @Published var isConnected: Bool = false
    @Published var isRecording: Bool = false
    @Published var transcription: String = ""
    @Published var errorMessage: String?
    
    // MARK: - Components
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    
    private let serverHost: String
    private var frameCount: Int = 0
    private var lastLogTime: Date = Date()
    
    // MARK: - Initialization
    
    init(serverHost: String = "192.168.1.64:8000") {
        self.serverHost = serverHost
        super.init()
    }
    
    // MARK: - Connection Management
    
    func connect() async {
        guard !isConnected else { return }
        
        // If your server uses a specific port, add it here:
        // let urlString = "ws://\(serverHost):8000/ws/stt"
        let urlString = "ws://\(serverHost)/ws/stt"
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid server URL"
            return
        }
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        print("🔌 Connecting to \(urlString)...")
        
        // Start receiving messages
        Task {
            await receiveMessages()
        }
        
        // Wait for "ready" message from server
        do {
            let readyMessage = try await receiveMessage()
            print("📨 Server ready: \(readyMessage)")
            isConnected = true
        } catch {
            errorMessage = "Connection failed: \(error.localizedDescription)"
            print("❌ Connection error: \(error)")
        }
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        stopRecording()
        print("🔌 Disconnected")
    }
    
    // MARK: - Audio Recording
    
    func startRecording() async throws {
        guard isConnected else {
            throw AudioStreamError.notConnected
        }
        
        // Request microphone permission
        #if !targetEnvironment(simulator)
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            throw AudioStreamError.permissionDenied
        }
        #endif
        
        // Setup audio engine
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }
        
        inputNode = engine.inputNode
        guard let input = inputNode else { return }
        
        // Configure audio format: 16kHz, mono, float32
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )
        
        guard let audioFormat = format else {
            throw AudioStreamError.audioSetupFailed
        }
        
        print("🎤 Audio format: \(audioFormat)")
        print("   Sample rate: \(sampleRate) Hz")
        print("   Frame size: \(frameMs) ms = \(samplesPerFrame) samples")
        
        // Install tap on input node
        input.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(samplesPerFrame),
            format: audioFormat
        ) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }
        
        // Start audio engine
        try engine.start()
        isRecording = true
        frameCount = 0
        lastLogTime = Date()
        
        print("✅ Recording started")
    }
    
    func stopRecording() {
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        audioEngine = nil
        inputNode = nil
        isRecording = false
        print("⏹️ Recording stopped")
    }
    
    // MARK: - Audio Processing
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let floatChannelData = buffer.floatChannelData else { return }
        
        let frameLength = Int(buffer.frameLength)
        let channelData = floatChannelData[0]
        
        // Convert float32 to PCM16
        var pcm16Data = Data()
        pcm16Data.reserveCapacity(frameLength * 2)
        
        for i in 0..<frameLength {
            let sample = channelData[i]
            // Clip to [-1.0, 1.0]
            let clipped = max(-1.0, min(1.0, sample))
            // Convert to int16
            let pcm16 = Int16(clipped * 32767.0)
            // Append as little-endian bytes
            withUnsafeBytes(of: pcm16.littleEndian) { bytes in
                pcm16Data.append(contentsOf: bytes)
            }
        }
        
        // Send via WebSocket
        Task { [weak self] in
            await self?.sendAudioFrame(pcm16Data)
        }
        
        // Log statistics every second
        frameCount += 1
        let now = Date()
        if now.timeIntervalSince(lastLogTime) >= 1.0 {
            print("📊 [client] sent \(frameCount) frames/sec, last=\(pcm16Data.count) bytes")
            frameCount = 0
            lastLogTime = now
        }
    }
    
    // MARK: - WebSocket Communication
    
    private func sendAudioFrame(_ data: Data) async {
        guard let task = webSocketTask else { return }
        
        let message = URLSessionWebSocketTask.Message.data(data)
        
        do {
            try await task.send(message)
        } catch {
            print("❌ Send error: \(error)")
            await MainActor.run {
                errorMessage = "Send failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func receiveMessages() async {
        while isConnected {
            do {
                let message = try await receiveMessage()
                await MainActor.run {
                    transcription = message
                    print("📝 Transcription: \(message)")
                }
            } catch {
                if !Task.isCancelled {
                    print("❌ Receive error: \(error)")
                }
                break
            }
        }
    }
    
    private func receiveMessage() async throws -> String {
        guard let task = webSocketTask else {
            throw AudioStreamError.notConnected
        }
        
        let message = try await task.receive()
        
        switch message {
        case .string(let text):
            return text
        case .data(let data):
            return String(data: data, encoding: .utf8) ?? ""
        @unknown default:
            return ""
        }
    }
    
    // MARK: - Cleanup
    
    nonisolated deinit {
        Task { @MainActor in
            disconnect()
        }
    }
}

// MARK: - Error Types

enum AudioStreamError: LocalizedError {
    case notConnected
    case permissionDenied
    case audioSetupFailed
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to server"
        case .permissionDenied:
            return "Microphone permission denied"
        case .audioSetupFailed:
            return "Failed to setup audio"
        }
    }
}
