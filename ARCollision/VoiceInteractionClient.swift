//
//  VoiceInteractionClient.swift
//  EchoMineVPModule
//
//  Voice interaction client with VAD support for streaming STT
//

import Foundation
import AVFoundation
import Combine

/// Voice interaction client matching server protocol with VAD
///
/// Cleanup of main actor-isolated state must be done explicitly by calling `disconnect()`.
/// The `deinit` method cannot access main actor-isolated state and thus does not perform cleanup.
/// Make sure to call `disconnect()` before releasing the instance.
@MainActor
class VoiceInteractionClient: NSObject, ObservableObject {
    
    // MARK: - Server Response Types
    
    enum ServerMessage: Decodable {
        case ready(ReadyMessage)
        case speechStart
        case speechEnd
        case final(FinalMessage)
        case transcription(TranscriptionMessage)
        case answer(AnswerMessage)
        case error(ErrorMessage)
        
        enum CodingKeys: String, CodingKey {
            case type
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            
            switch type {
            case "ready":
                let msg = try ReadyMessage(from: decoder)
                self = .ready(msg)
            case "speech_start":
                self = .speechStart
            case "speech_end":
                self = .speechEnd
            case "final":
                let msg = try FinalMessage(from: decoder)
                self = .final(msg)
            case "transcription":
                let msg = try TranscriptionMessage(from: decoder)
                self = .transcription(msg)
            case "answer":
                let msg = try AnswerMessage(from: decoder)
                self = .answer(msg)
            case "error":
                let msg = try ErrorMessage(from: decoder)
                self = .error(msg)
            default:
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: [], debugDescription: "Unknown type: \(type)")
                )
            }
        }
    }
    
    struct ReadyMessage: Codable {
        let type: String
        let sampleRate: Int
        let frameMs: Int
        let frameBytes: Int
        let silenceCutoffMs: Int
        
        enum CodingKeys: String, CodingKey {
            case type
            case sampleRate = "sample_rate"
            case frameMs = "frame_ms"
            case frameBytes = "frame_bytes"
            case silenceCutoffMs = "silence_cutoff_ms"
        }
    }
    
    struct FinalMessage: Codable {
        let type: String
        let text: String
        let reason: String?
    }
    
    struct TranscriptionMessage: Codable {
        let type: String
        let text: String
    }
    
    struct AnswerMessage: Codable {
        let type: String
        let query: String
        let response: String
    }
    
    struct ErrorMessage: Codable {
        let type: String
        let stage: String
        let message: String
    }
    
    // MARK: - State
    
    @Published var isConnected: Bool = false
    @Published var isRecording: Bool = false
    @Published var isSpeaking: Bool = false  // Voice activity detected
    @Published var transcription: String = ""  // Your speech (STT result)
    @Published var ragAnswer: String = ""  // AI response (RAG result)
    @Published var allConversations: [(query: String, answer: String)] = []
    @Published var errorMessage: String?
    @Published var serverConfig: ReadyMessage?
    @Published var connectionStatus: String = "Not connected"  // Debug info
    @Published var lastServerMessage: String = "None"  // Debug info
    @Published var audioFramesSent: Int = 0  // Debug: frames sent counter
    
    // MARK: - Audio Configuration
    
    private let sampleRate: Double = 16000
    private let frameMs: Double = 20
    private var samplesPerFrame: Int {
        Int(sampleRate * frameMs / 1000)
    }
    
    // MARK: - Components
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioConverter: AVAudioConverter?
    private var audioBuffer: [Float] = []  // Buffer for accumulating resampled audio
    
    private let serverHost: String
    private let serverPort: Int
    private let serverEndpoint: String
    private var frameCount: Int = 0
    private var lastLogTime: Date = Date()
    
    // MARK: - Initialization
    
    init(serverHost: String = ServerConfig.shared.host, 
         serverPort: Int = ServerConfig.shared.port,
         serverEndpoint: String = ServerConfig.shared.endpoint) {
        self.serverHost = serverHost
        self.serverPort = serverPort
        self.serverEndpoint = serverEndpoint
        super.init()
    }
    
    // MARK: - Connection Management
    
    /// Disconnects from the server and cleans up all resources.
    ///
    /// This method must be called explicitly before deallocation to ensure proper cleanup.
    /// It is the only way to clean up actor-isolated state.
    @MainActor
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        stopRecording()
        isConnected = false
        connectionStatus = "🔌 Disconnected"
        // Reset any additional published properties if needed here
        print("🔌 Disconnected")
    }
    
    func connect() async {
        guard !isConnected else { return }
        
        // Build URL with explicit port
        let urlString: String
        if serverPort == 80 {
            urlString = "ws://\(serverHost)\(serverEndpoint)"
        } else {
            urlString = "ws://\(serverHost):\(serverPort)\(serverEndpoint)"
        }
        print("🌐 Full URL: \(urlString)")
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid server URL"
            connectionStatus = "❌ Invalid URL: \(urlString)"
            return
        }
        
        connectionStatus = "🔄 Connecting to \(urlString)..."
        print("🔌 Connecting to \(urlString)...")
        print("📍 Server Host: \(serverHost)")
        print("📍 Server Port: \(serverPort)")
        print("📍 Server Endpoint: \(serverEndpoint)")
        print("📍 Constructed URL: \(url)")
        print("📍 URL scheme: \(url.scheme ?? "none")")
        print("📍 URL host: \(url.host ?? "none")")
        print("📍 URL port: \(url.port.map { String($0) } ?? "none")")
        print("📍 URL path: \(url.path)")
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        connectionStatus = "⏳ Waiting for server response..."
        print("⏳ WebSocket task created and resumed, waiting for ready message...")
        
        // Wait for "ready" message from server first (before starting receive loop)
        do {
            connectionStatus = "📨 Receiving first message..."
            guard let task = webSocketTask else {
                throw VoiceInteractionError.notConnected
            }
            
            let rawMessage = try await task.receive()
            let message = try parseMessage(rawMessage)
            lastServerMessage = "Received: \(message)"
            
            if case .ready(let config) = message {
                serverConfig = config
                isConnected = true
                connectionStatus = "✅ Connected successfully!"
                print("📨 Server ready:")
                print("   Sample rate: \(config.sampleRate) Hz")
                print("   Frame: \(config.frameMs) ms (\(config.frameBytes) bytes)")
                print("   Silence cutoff: \(config.silenceCutoffMs) ms")
                
                // Now start the receive loop AFTER we're connected
                Task {
                    await receiveMessages()
                }
            } else {
                connectionStatus = "⚠️ Unexpected first message: \(message)"
                print("⚠️ First message was not 'ready': \(message)")
            }
        } catch {
            let errorDetail = error.localizedDescription
            errorMessage = "Connection failed: \(errorDetail)"
            connectionStatus = "❌ Failed: \(errorDetail)"
            print("❌ Connection error: \(error)")
            print("❌ Error type: \(type(of: error))")
            
            // Additional debugging for common errors
            if let urlError = error as? URLError {
                print("❌ URLError code: \(urlError.code.rawValue)")
                print("❌ URLError description: \(urlError.localizedDescription)")
                
                // Check for 403 Forbidden
                if urlError.code.rawValue == -1011 {
                    connectionStatus = "❌ Server rejected connection (403 Forbidden)"
                    errorMessage = "Server rejected connection. Check server-side origin/CORS settings."
                    print("⚠️ HTTP 403 Forbidden - Server is rejecting this client")
                }
            }
            
            // Check for POSIXError (low-level socket errors)
            if let posixError = error as? POSIXError {
                print("❌ POSIX error code: \(posixError.code.rawValue)")
            }
        }
    }
    
    // MARK: - Audio Recording
    
    func startRecording() async throws {
        guard isConnected else {
            throw VoiceInteractionError.notConnected
        }
        
        // Reset counter and buffer
        audioFramesSent = 0
        audioBuffer.removeAll()
        audioConverter = nil
        
        // Request microphone permission (visionOS compatible)
        #if !targetEnvironment(simulator)
        // visionOS uses AVAudioApplication for audio permissions
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            throw VoiceInteractionError.permissionDenied
        }
        #else
        // Simulator: Skip permission check
        print("⚠️ Running on simulator - skipping microphone permission")
        #endif
        
        // Setup audio engine
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }
        
        inputNode = engine.inputNode
        guard let input = inputNode else { return }
        
        // Get the input node's native format (usually 48kHz on modern devices)
        let inputFormat = input.outputFormat(forBus: 0)
        print("🎤 Input node native format: \(inputFormat)")
        print("   Native sample rate: \(inputFormat.sampleRate) Hz")
        print("   Native channels: \(inputFormat.channelCount)")
        
        // Configure our desired format: 16kHz, mono, float32
        guard let desiredFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw VoiceInteractionError.audioSetupFailed
        }
        
        print("🎯 Desired format: \(desiredFormat)")
        print("   Sample rate: \(sampleRate) Hz")
        print("   Frame size: \(frameMs) ms = \(samplesPerFrame) samples")
        
        // Install tap using the INPUT format (not our desired format)
        // We'll convert the audio ourselves
        input.installTap(
            onBus: 0,
            bufferSize: 1024, // Use a reasonable buffer size
            format: inputFormat // Use native format to avoid format mismatch
        ) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, targetFormat: desiredFormat)
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
        audioConverter = nil
        audioBuffer.removeAll()
        isRecording = false
        isSpeaking = false
        print("⏹️ Recording stopped")
    }
    
    // MARK: - Audio Processing
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat) {
        // Early exit if not connected - don't process audio if connection is dead
        guard isConnected else {
            return
        }
        
        guard let inputFormat = audioEngine?.inputNode.outputFormat(forBus: 0) else {
            print("⚠️ No input format available")
            return
        }
        
        // Create converter if needed (only once)
        if audioConverter == nil {
            guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
                print("❌ Failed to create audio converter")
                return
            }
            audioConverter = converter
            print("✅ Created audio converter: \(inputFormat.sampleRate)Hz → \(targetFormat.sampleRate)Hz")
            print("   Input channels: \(inputFormat.channelCount), Output channels: \(targetFormat.channelCount)")
        }
        
        guard let converter = audioConverter else { return }
        
        // Calculate output buffer size based on sample rate ratio
        let ratio = targetFormat.sampleRate / inputFormat.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
        
        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputFrameCapacity
        ) else {
            print("❌ Failed to create converted buffer")
            return
        }
        
        // Convert the audio
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        let status = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            print("❌ Conversion error: \(error)")
            return
        }
        
        if status == .error {
            print("❌ Conversion status: error")
            return
        }
        
        // Extract float samples from converted buffer
        guard let floatChannelData = convertedBuffer.floatChannelData else {
            print("⚠️ No float channel data in converted buffer")
            return
        }
        
        let frameLength = Int(convertedBuffer.frameLength)
        
        if frameLength == 0 {
            print("⚠️ Converted buffer has zero length")
            return
        }
        
        let channelData = floatChannelData[0]
        
        // Add samples to our accumulation buffer
        for i in 0..<frameLength {
            let sample = channelData[i]
            // Validate sample is not NaN or infinite
            if sample.isNaN || sample.isInfinite {
                audioBuffer.append(0.0)  // Replace invalid samples with silence
            } else {
                audioBuffer.append(sample)
            }
        }
        
        // Process complete 20ms frames (320 samples at 16kHz)
        while audioBuffer.count >= samplesPerFrame {
            let frameSamples = Array(audioBuffer.prefix(samplesPerFrame))
            audioBuffer.removeFirst(samplesPerFrame)
            
            // Convert float32 to PCM16
            var pcm16Data = Data()
            pcm16Data.reserveCapacity(samplesPerFrame * 2)
            
            for sample in frameSamples {
                // Clip to [-1.0, 1.0]
                let clipped = max(-1.0, min(1.0, sample))
                // Convert to int16
                let pcm16 = Int16(clipped * 32767.0)
                // Append as little-endian bytes
                withUnsafeBytes(of: pcm16.littleEndian) { bytes in
                    pcm16Data.append(contentsOf: bytes)
                }
            }
            
            // Verify we have exactly 640 bytes (320 samples * 2 bytes)
            if pcm16Data.count != 640 {
                print("⚠️ Frame size mismatch: got \(pcm16Data.count) bytes, expected 640")
                continue
            }
            
            // Send via WebSocket
            Task { [weak self] in
                await self?.sendAudioFrame(pcm16Data)
            }
            
            // Log statistics every second
            frameCount += 1
            let now = Date()
            if now.timeIntervalSince(lastLogTime) >= 1.0 {
                print("📊 [client] sent \(frameCount) frames/sec, buffer=\(audioBuffer.count) samples")
                frameCount = 0
                lastLogTime = now
            }
        }
    }
    
    // MARK: - WebSocket Communication
    
    
    private func sendAudioFrame(_ data: Data) async {
        // Check if still connected before sending
        guard isConnected else {
            return  // Silently skip if not connected
        }
        
        guard let task = webSocketTask else {
            return  // Silently skip if no task
        }
        
        let message = URLSessionWebSocketTask.Message.data(data)
        
        do {
            try await task.send(message)
            await MainActor.run {
                audioFramesSent += 1
            }
        } catch {
            // Check error type
            if let urlError = error as? URLError {
                if urlError.code == .cancelled {
                    // Normal during disconnect, ignore
                    return
                }
                print("❌ Send URLError: \(urlError.code) - \(urlError.localizedDescription)")
            } else if let posixError = error as? POSIXError {
                if posixError.code.rawValue == 89 {  // ECANCELED
                    // Connection was cancelled, ignore
                    return
                }
                print("❌ Send POSIX error: \(posixError.code.rawValue) - \(posixError.localizedDescription)")
            } else {
                print("❌ Send error: \(error)")
            }
            
            // Mark as disconnected on send failure
            await MainActor.run {
                isConnected = false
                connectionStatus = "❌ Send failed - disconnected"
                errorMessage = "Failed to send audio: \(error.localizedDescription)"
            }
        }
    }
    
    private func receiveMessages() async {
        print("📨 Starting message receive loop...")
        
        while isConnected {
            do {
                guard let task = webSocketTask else {
                    print("⚠️ No WebSocket task, stopping receive loop")
                    break
                }
                
                // Receive message without timeout - let the server control timing
                let message = try await task.receive()
                
                // Parse and handle the message
                let serverMessage = try parseMessage(message)
                await handleServerMessage(serverMessage)
                
            } catch {
                // Check if it's a cancellation (normal when disconnecting)
                if Task.isCancelled {
                    print("✅ Message receive loop cancelled (normal)")
                    break
                }
                
                // Check if connection was closed
                if let urlError = error as? URLError {
                    if urlError.code == .cancelled {
                        print("✅ WebSocket cancelled (normal)")
                        break
                    }
                    
                    print("❌ URLError in receive: \(urlError.code) - \(urlError.localizedDescription)")
                    
                    // Connection is truly broken, stop the loop
                    await MainActor.run {
                        isConnected = false
                        connectionStatus = "❌ Connection lost"
                        errorMessage = "Connection lost: \(urlError.localizedDescription)"
                    }
                    break
                }
                
                // Log unexpected errors
                print("⚠️ Receive error: \(error)")
                print("   Error type: \(type(of: error))")
                
                // For other errors, mark as disconnected
                await MainActor.run {
                    isConnected = false
                    connectionStatus = "❌ Connection error"
                    errorMessage = "Connection error: \(error.localizedDescription)"
                }
                break
            }
        }
        
        print("📭 Message receive loop ended")
    }
    
    private func parseMessage(_ message: URLSessionWebSocketTask.Message) throws -> ServerMessage {
        switch message {
        case .string(let text):
            print("📥 Received string message: \(text.prefix(100))...")
            let data = text.data(using: .utf8) ?? Data()
            let decoder = JSONDecoder()
            return try decoder.decode(ServerMessage.self, from: data)
            
        case .data(let data):
            print("📥 Received data message: \(data.count) bytes")
            let decoder = JSONDecoder()
            return try decoder.decode(ServerMessage.self, from: data)
            
        @unknown default:
            throw VoiceInteractionError.unknownMessageType
        }
    }
    
    
    private func handleServerMessage(_ message: ServerMessage) async {
        await MainActor.run {
            lastServerMessage = "Last: \(message)"
            
            switch message {
            case .ready(let config):
                serverConfig = config
                print("✅ Server ready")
                
            case .speechStart:
                isSpeaking = true
                print("🗣️ Speech started")
                
            case .speechEnd:
                isSpeaking = false
                print("🤐 Speech ended")
                
            case .transcription(let msg):
                transcription = msg.text
                print("📝 Transcription: \(msg.text)")
                
            case .answer(let msg):
                ragAnswer = msg.response
                allConversations.append((query: msg.query, answer: msg.response))
                print("🤖 AI Answer: \(msg.response)")
                
            case .final(let msg):
                if msg.text.isEmpty {
                    print("⚠️ No transcription (reason: \(msg.reason ?? "unknown"))")
                } else {
                    // Show final transcription
                    transcription = msg.text
                    print("✅ Final transcription: \(msg.text)")
                }
                
            case .error(let err):
                errorMessage = "Server error [\(err.stage)]: \(err.message)"
                print("❌ Server error: \(err.stage) - \(err.message)")
            }
        }
    }
    
    // Cleanup of main actor-isolated state must be done explicitly before deallocation.
    // Deinit cannot access main actor state.
    deinit {
        // Intentionally left empty. Call `disconnect()` explicitly to clean up resources.
    }
}

// MARK: - Error Types

enum VoiceInteractionError: LocalizedError {
    case notConnected
    case permissionDenied
    case audioSetupFailed
    case unknownMessageType
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to server"
        case .permissionDenied:
            return "Microphone permission denied"
        case .audioSetupFailed:
            return "Failed to setup audio"
        case .unknownMessageType:
            return "Unknown message type from server"
        }
    }
}

