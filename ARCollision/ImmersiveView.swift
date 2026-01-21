//
//  ImmersiveView.swift
//  ARCollision
//
//  Created by 徐暐博 on 1/9/26.
//

import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

struct ImmersiveView: View {
    @Environment(AppModel.self) var appModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        RealityView { content in
            // Add the model's setup content entity
            content.add(appModel.setupContentEntity())
        }
        .task {
            // Start the ARKit session with scene reconstruction and hand tracking
            print("🚀 Starting AR session...")
            print("   Providers supported: \(appModel.dataProvidersAreSupported)")
            print("   Scene reconstruction state: \(appModel.sceneReconstruction.state)")
            print("   Hand tracking state: \(appModel.handTracking.state)")
            
            do {
                guard appModel.dataProvidersAreSupported else {
                    print("❌ Data providers not supported on this device")
                    await dismissImmersiveSpace()
                    return
                }
                
                // Request authorization for world sensing (required for scene reconstruction)
                print("🔐 Requesting world sensing authorization...")
                let authorizationResult = await appModel.session.requestAuthorization(for: [.worldSensing, .handTracking])
                
                for (authorizationType, authorizationStatus) in authorizationResult {
                    print("   \(authorizationType): \(authorizationStatus)")
                    if authorizationStatus == .denied {
                        print("❌ \(authorizationType) authorization denied - app functionality will be limited")
                    }
                }
                
                print("✅ Starting session with providers...")
                print("   SceneReconstructionProvider state before run: \(appModel.sceneReconstruction.state)")
                print("   HandTrackingProvider state before run: \(appModel.handTracking.state)")
                
                try await appModel.session.run([appModel.sceneReconstruction, appModel.handTracking])
                
                print("✅ Session started successfully!")
                print("   SceneReconstructionProvider state after run: \(appModel.sceneReconstruction.state)")
                print("   HandTrackingProvider state after run: \(appModel.handTracking.state)")
                
                // Give the system a moment to start providing data
                try await Task.sleep(for: .seconds(0.5))
                print("🔍 Scene reconstruction should now be active and scanning")
                
            } catch {
                print("❌ Failed to start session: \(error)")
                await dismissImmersiveSpace()
                openWindow(id: "error")
            }
        }
        .task {
            // Continuously process hand tracking updates
            await appModel.processHandUpdates()
        }
        .task {
            // Monitor ARKit session events (interruptions, errors, etc.)
            await appModel.monitorSessionEvents()
        }
        .task(priority: .low) {
            // Process scene reconstruction mesh updates at low priority
            await appModel.processReconstructionUpdates()
        }
        .gesture(
            // Tap on entities to place cube at exact tap location
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    let location3D = value.convert(value.location3D, from: .global, to: .scene)
                    appModel.addCube(tapLocation: location3D)
                }
        )
    }
}

// Preview removed - requires full AppModel implementation with ARKit session

