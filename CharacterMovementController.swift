//
//  CharacterMovementController.swift
//  ARCollision
//
//  Created on 1/21/26.
//

import RealityKit
import Combine
import Foundation
import SwiftUI

@MainActor
class CharacterMovementController: ObservableObject {
    // Character entity reference
    var characterEntity: Entity
    
    // Movement state
    @Published var velocity: SIMD3<Float> = .zero
    @Published var isOnGround: Bool = false
    @Published var currentSpeed: Float = 0.0
    
    // Movement parameters
    let walkSpeed: Float = 1.0  // 1 meter per second
    let turnSpeed: Float = Float.pi / 2  // 90 degrees per second
    let gravity: SIMD3<Float> = [0, -9.8, 0]  // Earth gravity
    
    // Current movement command
    private var movementDirection: SIMD3<Float> = .zero
    private var isMoving = false
    private var lastLogTime: TimeInterval = 0
    
    init(characterEntity: Entity) {
        self.characterEntity = characterEntity
        print("🎮 CharacterMovementController initialized")
    }
    
    // MARK: - Movement Commands
    
    func moveForward() {
        print("⬆️ Moving forward")
        // Get the character's forward direction
        let forward = characterEntity.transform.matrix.columns.2
        movementDirection = normalize(SIMD3<Float>(forward.x, 0, forward.z))
        isMoving = true
    }
    
    func moveBackward() {
        print("⬇️ Moving backward")
        // Get the character's backward direction
        let forward = characterEntity.transform.matrix.columns.2
        movementDirection = -normalize(SIMD3<Float>(forward.x, 0, forward.z))
        isMoving = true
    }
    
    func turnLeft() {
        print("↰ Turning left")
        // Rotate character 90 degrees counter-clockwise
        let currentRotation = characterEntity.orientation
        let leftTurn = simd_quatf(angle: Float.pi / 2, axis: [0, 1, 0])
        characterEntity.orientation = currentRotation * leftTurn
    }
    
    func turnRight() {
        print("↱ Turning right")
        // Rotate character 90 degrees clockwise
        let currentRotation = characterEntity.orientation
        let rightTurn = simd_quatf(angle: -Float.pi / 2, axis: [0, 1, 0])
        characterEntity.orientation = currentRotation * rightTurn
    }
    
    func stop() {
        print("⏹️ Stopping")
        movementDirection = .zero
        isMoving = false
        velocity = .zero
    }
    
    // MARK: - Update Loop
    
    func update(deltaTime: Float) {
        // Read state from CharacterControllerStateComponent if available
        if let stateComponent = characterEntity.components[CharacterControllerStateComponent.self] {
            velocity = stateComponent.velocity
            isOnGround = stateComponent.isOnGround
            currentSpeed = length(SIMD3<Float>(velocity.x, 0, velocity.z))
        }
        
        // Apply gravity if not on ground
        if !isOnGround {
            velocity += gravity * deltaTime
        } else {
            // On ground, reset vertical velocity
            velocity.y = 0
        }
        
        // Apply horizontal movement
        if isMoving {
            let horizontalVelocity = movementDirection * walkSpeed
            velocity.x = horizontalVelocity.x
            velocity.z = horizontalVelocity.z
        } else {
            // Not moving, stop horizontal movement
            velocity.x = 0
            velocity.z = 0
        }
        
        // Move the character using CharacterControllerComponent
        let movement = velocity * deltaTime
        
        characterEntity.moveCharacter(
            by: movement,
            deltaTime: deltaTime,
            relativeTo: nil
        ) { collision in
            self.handleCollision(collision)
        }
        
        // Log occasionally for debugging (every 3 seconds)
        let currentTime = CACurrentMediaTime()
        if currentTime - lastLogTime > 3.0 {
            lastLogTime = currentTime
            print("🚶 Character state:")
            print("   Position: \(characterEntity.position(relativeTo: nil))")
            print("   Velocity: \(velocity)")
            print("   On Ground: \(isOnGround)")
            print("   Speed: \(currentSpeed) m/s")
        }
    }
    
    // MARK: - Collision Handling
    
    private func handleCollision(_ collision: CharacterControllerComponent.Collision) {
        print("💥 Character collided!")
        print("   Hit entity: \(collision.hitEntity.name)")
        
        // Collision struct only has hitEntity in visionOS
        // You can add logic here, like:
        // - Playing collision sound
        // - Stopping movement
        // - Triggering animations
        // - Checking if hit a special object
    }
}
