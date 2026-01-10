//
//  ContentView.swift
//  ARCollision
//
//  Created by 徐暐博 on 1/9/26.
//

import SwiftUI
import RealityKit

struct ContentView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(spacing: 20) {
            ToggleImmersiveSpaceButton()
            
            if appModel.immersiveSpaceState == .open {
                VStack(spacing: 15) {
                    Text("👌 Pinch to Spawn Cubes")
                        .font(.headline)
                    
                    Text("Use your thumb and index finger to pinch")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Divider()
                    
                    // Debug info visible in Vision Pro
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🐛 Debug Info:")
                            .font(.caption)
                            .bold()
                        
                        HStack {
                            Text("Left Hand:")
                                .font(.caption2)
                            Text(appModel.leftHandPosition != nil ? "✅ Tracked" : "❌ Not visible")
                                .font(.caption2)
                                .foregroundStyle(appModel.leftHandPosition != nil ? .green : .red)
                        }
                        
                        HStack {
                            Text("Right Hand:")
                                .font(.caption2)
                            Text(appModel.rightHandPosition != nil ? "✅ Tracked" : "❌ Not visible")
                                .font(.caption2)
                                .foregroundStyle(appModel.rightHandPosition != nil ? .green : .red)
                        }
                        
                        if let rightPos = appModel.rightHandPosition {
                            Text("Position: (\(String(format: "%.2f", rightPos.x)), \(String(format: "%.2f", rightPos.y)), \(String(format: "%.2f", rightPos.z)))")
                                .font(.caption2)
                                .monospaced()
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
                .padding()
            }
        }
        .padding()
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
