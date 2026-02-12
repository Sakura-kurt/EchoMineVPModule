//
//  ServerConfig.swift
//  EchoMineVPModule
//
//  Centralized server configuration for voice services
//

import Foundation
import Combine

/// Centralized server configuration
class ServerConfig: ObservableObject {
    /// Shared instance
    static let shared = ServerConfig()
    
    /// Server host IP address
    @Published var host: String = {
        UserDefaults.standard.string(forKey: "serverHost") ?? "172.20.10.3"
    }()
    
    /// Server port (must match your Python server)
    @Published var port: Int = {
        UserDefaults.standard.integer(forKey: "serverPort") != 0 
            ? UserDefaults.standard.integer(forKey: "serverPort") 
            : 8000
    }()
    
    /// WebSocket endpoint - use /ws/stt for simple STT, /ws/chat for STT+RAG server
    @Published var endpoint: String = {
        UserDefaults.standard.string(forKey: "serverEndpoint") ?? "/ws/stt"
    }()
    
    /// Full WebSocket URL
    var webSocketURL: String {
        "ws://\(host):\(port)\(endpoint)"
    }
    
    private init() {}
    
    /// Update configuration
    func update(host: String, port: Int) {
        self.host = host
        self.port = port
        UserDefaults.standard.set(host, forKey: "serverHost")
        UserDefaults.standard.set(port, forKey: "serverPort")
    }
    
    // MARK: - Quick Presets
    
    /// Use when testing on the same device (iOS Simulator)
    static let localhost = "127.0.0.1"
    
    /// iPhone Personal Hotspot
    static let hotspot = "172.20.10.3"
    
    /// Common local network ranges (update with your actual IP)
    static let exampleLocalIP = "192.168.1.XXX"
}

// MARK: - Usage Examples
/*
 
 To update the server IP address:
 
 1. Find your computer's IP:
    ```bash
    ipconfig getifaddr en0
    # Output: 192.168.1.123
    ```
 
 2. Update ServerConfig.host:
    ```swift
    static let host: String = "192.168.1.123"
    ```
 
 3. Make sure both devices are on the same Wi-Fi network
 
 4. Verify your Python server is running:
    ```bash
    python server.py
    # Should show: Server listening on ws://0.0.0.0:8001/ws/chat
    ```
 
 */
