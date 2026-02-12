//
//  AppModel.swift
//  ARCollision
//
//  Created by 徐暐博 on 1/9/26.
//

import SwiftUI
import RealityKit
import ARKit

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed
    
    // MARK: - ARKit Session & Providers
    let session = ARKitSession()
    let sceneReconstruction = SceneReconstructionProvider(modes: [.classification])
    let handTracking = HandTrackingProvider()
    
    // MARK: - Content Entity Management
    let contentEntity = Entity()
    private var meshEntities: [UUID: ModelEntity] = [:]
    
    // MARK: - Hand Tracking State
    var leftHandPosition: SIMD3<Float>?
    var rightHandPosition: SIMD3<Float>?
    
    // MARK: - Computed Properties
    
    /// Check if the required data providers are supported on this device
    var dataProvidersAreSupported: Bool {
        SceneReconstructionProvider.isSupported && HandTrackingProvider.isSupported
    }
    
    /// Check if the app is ready to start the AR session
    var isReadyToRun: Bool {
        sceneReconstruction.state == .initialized && handTracking.state == .initialized
    }
    
    // MARK: - Setup Methods
    
    /// Setup and return the root content entity for the immersive space
    func setupContentEntity() -> Entity {
        // Add a few initial cubes to interact with
        addInitialCubes()
        return contentEntity
    }
    
    /// Add some initial cubes to the scene so there's something to see
    private func addInitialCubes() {
        // Add a cube 1 meter in front of the user
        let cube1 = ModelEntity(
            mesh: .generateBox(size: 0.1),
            materials: [SimpleMaterial(color: .systemRed, isMetallic: false)]
        )
        cube1.position = [0, 1.5, -1.0] // In front at eye level
        cube1.collision = CollisionComponent(shapes: [.generateBox(size: [0.1, 0.1, 0.1])])
        cube1.physicsBody = PhysicsBodyComponent(massProperties: .default, mode: .dynamic)
        cube1.components.set(InputTargetComponent())
        contentEntity.addChild(cube1)
        
        // Add another cube to the side
        let cube2 = ModelEntity(
            mesh: .generateBox(size: 0.15),
            materials: [SimpleMaterial(color: .systemGreen, isMetallic: false)]
        )
        cube2.position = [0.5, 1.5, -1.2]
        cube2.collision = CollisionComponent(shapes: [.generateBox(size: [0.15, 0.15, 0.15])])
        cube2.physicsBody = PhysicsBodyComponent(massProperties: .default, mode: .dynamic)
        cube2.components.set(InputTargetComponent())
        contentEntity.addChild(cube2)
        
        // Add a third cube
        let cube3 = ModelEntity(
            mesh: .generateBox(size: 0.12),
            materials: [SimpleMaterial(color: .systemBlue, isMetallic: false)]
        )
        cube3.position = [-0.5, 1.5, -1.0]
        cube3.collision = CollisionComponent(shapes: [.generateBox(size: [0.12, 0.12, 0.12])])
        cube3.physicsBody = PhysicsBodyComponent(massProperties: .default, mode: .dynamic)
        cube3.components.set(InputTargetComponent())
        contentEntity.addChild(cube3)
    }
    
    // MARK: - Hand Tracking
    
    /// Process hand tracking updates continuously
    func processHandUpdates() async {
        for await update in handTracking.anchorUpdates {
            let handAnchor = update.anchor
            
            guard handAnchor.isTracked else { continue }
            
            // Get index finger tip and thumb tip positions
            if let indexFingerTip = handAnchor.handSkeleton?.joint(.indexFingerTip),
               let thumbTip = handAnchor.handSkeleton?.joint(.thumbTip) {
                
                let indexPos = SIMD3<Float>(
                    indexFingerTip.anchorFromJointTransform.columns.3.x,
                    indexFingerTip.anchorFromJointTransform.columns.3.y,
                    indexFingerTip.anchorFromJointTransform.columns.3.z
                )
                
                let thumbPos = SIMD3<Float>(
                    thumbTip.anchorFromJointTransform.columns.3.x,
                    thumbTip.anchorFromJointTransform.columns.3.y,
                    thumbTip.anchorFromJointTransform.columns.3.z
                )
                
                // Store position based on which hand
                switch handAnchor.chirality {
                case .left:
                    leftHandPosition = indexPos
                case .right:
                    rightHandPosition = indexPos
                }
                
                // Detect pinch gesture (thumb and index finger close together)
                let distance = simd_distance(indexPos, thumbPos)
                detectPinch(distance: distance, position: indexPos, chirality: handAnchor.chirality)
            }
        }
    }
    
    // Pinch detection state
    private var wasLeftPinching = false
    private var wasRightPinching = false
    private let pinchThreshold: Float = 0.02 // 2cm
    
    /// Detect pinch gesture and spawn cube
    private func detectPinch(distance: Float, position: SIMD3<Float>, chirality: HandAnchor.Chirality) {
        let isPinching = distance < pinchThreshold
        
        switch chirality {
        case .left:
            if isPinching && !wasLeftPinching {
                // Pinch started
                print("🤏 Left hand pinch detected at distance: \(distance)m")
                addCube(tapLocation: position)
            }
            wasLeftPinching = isPinching
            
        case .right:
            if isPinching && !wasRightPinching {
                // Pinch started
                print("🤏 Right hand pinch detected at distance: \(distance)m")
                addCube(tapLocation: position)
            }
            wasRightPinching = isPinching
        }
    }
    
    /// Get the current hand position (prefers right hand, falls back to left)
    func getCurrentHandPosition() -> SIMD3<Float>? {
        return rightHandPosition ?? leftHandPosition
    }
    
    // MARK: - Session Monitoring
    
    /// Monitor ARKit session events for errors and interruptions
    func monitorSessionEvents() async {
        print("👁️ Session monitoring started")
        for await event in session.events {
            switch event {
            case .authorizationChanged(let type, let status):
                print("🔐 Authorization changed for \(type): \(status)")
                if status == .denied {
                    print("❌ Authorization denied - scene reconstruction may not work")
                }
            case .dataProviderStateChanged(let providers, let newState, let error):
                print("🔄 Data provider state changed: \(newState)")
                print("   Providers affected: \(providers)")
                if let error {
                    print("❌ Error: \(error)")
                }
                
                // Check specifically for scene reconstruction provider
                if providers.contains(where: { $0 is SceneReconstructionProvider }) {
                    print("📡 SceneReconstructionProvider state: \(sceneReconstruction.state)")
                }
            @unknown default:
                print("❓ Unknown session event")
            }
        }
    }
    
    // MARK: - Scene Reconstruction
    
    /// Process scene reconstruction mesh updates
    func processReconstructionUpdates() async {
        print("🔍 Scene reconstruction update loop started")
        var anchorCount = 0
        
        for await update in sceneReconstruction.anchorUpdates {
            anchorCount += 1
            let meshAnchor = update.anchor
            
            // Log the position of this mesh anchor
            let position = meshAnchor.originFromAnchorTransform.columns.3
            print("📍 Mesh anchor update #\(anchorCount) - Event: \(update.event) - Position: (\(position.x), \(position.y), \(position.z))")
            
            switch update.event {
            case .added:
                // Generate collision shape for the new mesh
                guard let shape = try? await ShapeResource.generateStaticMesh(from: meshAnchor) else {
                    print("⚠️ Failed to generate collision shape for new mesh anchor: \(meshAnchor.id)")
                    continue
                }
                
                let entity = ModelEntity()
                entity.transform = Transform(matrix: meshAnchor.originFromAnchorTransform)
                entity.collision = CollisionComponent(shapes: [shape], isStatic: true)
                entity.components.set(InputTargetComponent())
                entity.physicsBody = PhysicsBodyComponent(mode: .static)
                
                // Add semi-transparent material so you can see the scanned meshes
                // Using pure light pink color (纯粉色，不偏黄) - visionOS compatible
                if let mesh = try? await MeshResource(from: meshAnchor) {
                    var material = SimpleMaterial()
                    // SwiftUI Color for visionOS (R=1.0, G=0.6, B=0.85, alpha=0.6)
                    material.color = .init(tint: .init(red: 1.0, green: 0.6, blue: 0.85, alpha: 0.6))
                    entity.model = ModelComponent(mesh: mesh, materials: [material])
                }
                
                meshEntities[meshAnchor.id] = entity
                contentEntity.addChild(entity)
                print("✅ Added mesh anchor: \(meshAnchor.id) - Total meshes: \(meshEntities.count)")
                
            case .updated:
                guard let entity = meshEntities[meshAnchor.id] else {
                    print("⚠️ Received update for unknown mesh anchor: \(meshAnchor.id)")
                    continue
                }
                
                // Generate NEW collision shape for the UPDATED mesh
                guard let shape = try? await ShapeResource.generateStaticMesh(from: meshAnchor) else {
                    print("⚠️ Failed to generate collision shape for updated mesh anchor: \(meshAnchor.id)")
                    continue
                }
                
                entity.transform = Transform(matrix: meshAnchor.originFromAnchorTransform)
                entity.collision = CollisionComponent(shapes: [shape], isStatic: true)
                
                // Update the visual mesh too with pure light pink color (纯粉色，不偏黄) - visionOS compatible
                if let mesh = try? await MeshResource(from: meshAnchor) {
                    var material = SimpleMaterial()
                    // SwiftUI Color for visionOS (R=1.0, G=0.6, B=0.85, alpha=0.6)
                    material.color = .init(tint: .init(red: 1.0, green: 0.6, blue: 0.85, alpha: 0.6))
                    entity.model = ModelComponent(mesh: mesh, materials: [material])
                }
                print("🔄 Updated mesh anchor: \(meshAnchor.id) - Total meshes: \(meshEntities.count)")
                
            case .removed:
                meshEntities[meshAnchor.id]?.removeFromParent()
                meshEntities.removeValue(forKey: meshAnchor.id)
                print("🗑️ Removed mesh anchor: \(meshAnchor.id) - Total meshes: \(meshEntities.count)")
            }
        }
        
        print("⚠️ Scene reconstruction update loop ended unexpectedly")
    }
    
    // MARK: - Interaction
    
    /// Add a cube at the tapped location in 3D space
    func addCube(tapLocation: SIMD3<Float>) {
        let cube = ModelEntity(
            mesh: .generateBox(size: 0.1),
            materials: [SimpleMaterial(color: .blue, isMetallic: false)]
        )
        
        cube.position = tapLocation
        
        // Add physics for collision detection
        cube.collision = CollisionComponent(shapes: [.generateBox(size: [0.1, 0.1, 0.1])])
        cube.physicsBody = PhysicsBodyComponent(
            massProperties: .default,
            mode: .dynamic
        )
        
        // Make it tappable
        cube.components.set(InputTargetComponent())
        
        contentEntity.addChild(cube)
    }
}
