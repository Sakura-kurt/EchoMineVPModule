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
    let sceneReconstruction = SceneReconstructionProvider()
    let handTracking = HandTrackingProvider()
    
    // MARK: - Content Entity Management
    let contentEntity = Entity()
    private var meshEntities: [UUID: ModelEntity] = [:]
    
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
            
            // Access hand skeleton and joints
            guard handAnchor.isTracked else { continue }
            
            // You can process hand data here
            // Example: Get index finger tip position
            if let indexFingerTip = handAnchor.handSkeleton?.joint(.indexFingerTip) {
                let position = indexFingerTip.anchorFromJointTransform.columns.3
                // Do something with hand position
                // print("Hand \(handAnchor.chirality): \(position)")
            }
        }
    }
    
    // MARK: - Session Monitoring
    
    /// Monitor ARKit session events for errors and interruptions
    func monitorSessionEvents() async {
        for await event in session.events {
            switch event {
            case .authorizationChanged(let type, let status):
                print("Authorization changed for \(type): \(status)")
                if status == .denied {
                    // Handle denied authorization
                }
            case .dataProviderStateChanged(let providers, let newState, let error):
                print("Data provider state changed: \(newState)")
                if let error {
                    print("Error: \(error)")
                }
            @unknown default:
                print("Unknown session event")
            }
        }
    }
    
    // MARK: - Scene Reconstruction
    
    /// Process scene reconstruction mesh updates
    func processReconstructionUpdates() async {
        for await update in sceneReconstruction.anchorUpdates {
            let meshAnchor = update.anchor
            
            guard let shape = try? await ShapeResource.generateStaticMesh(from: meshAnchor) else { continue }
            switch update.event {
            case .added:
                let entity = ModelEntity()
                entity.transform = Transform(matrix: meshAnchor.originFromAnchorTransform)
                entity.collision = CollisionComponent(shapes: [shape], isStatic: true)
                entity.components.set(InputTargetComponent())
                entity.physicsBody = PhysicsBodyComponent(mode: .static)
                
                // Add semi-transparent material so you can see the scanned meshes
                if let mesh = try? await MeshResource(from: meshAnchor) {
                    var material = SimpleMaterial()
                    material.color = .init(tint: .white.withAlphaComponent(0.3))
                    entity.model = ModelComponent(mesh: mesh, materials: [material])
                }
                
                meshEntities[meshAnchor.id] = entity
                contentEntity.addChild(entity)
            case .updated:
                guard let entity = meshEntities[meshAnchor.id] else { continue }
                entity.transform = Transform(matrix: meshAnchor.originFromAnchorTransform)
                entity.collision = CollisionComponent(shapes: [shape], isStatic: true)
                
                // Update the visual mesh too
                if let mesh = try? await MeshResource(from: meshAnchor) {
                    var material = SimpleMaterial()
                    material.color = .init(tint: .white.withAlphaComponent(0.3))
                    entity.model = ModelComponent(mesh: mesh, materials: [material])
                }
            case .removed:
                meshEntities[meshAnchor.id]?.removeFromParent()
                meshEntities.removeValue(forKey: meshAnchor.id)
            }
        }
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
