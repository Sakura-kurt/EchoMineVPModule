//
//  CharacterMovementView.swift
//  ARCollision
//
//  Created on 1/21/26.
//

import SwiftUI
import RealityKit
import ARKit

struct CharacterMovementView: View {
    @Environment(AppModel.self) var appModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    
    @StateObject private var characterController = CharacterMovementController(characterEntity: Entity())
    @State private var rootEntity = Entity()
    
    var body: some View {
        ZStack {
            RealityView { content in
                // Add the app's reconstructed environment
                content.add(appModel.contentEntity)
                
                // Add root entity for our character
                content.add(rootEntity)
                
                // Add lighting
                setupLighting(in: content)
            }
            .task {
                // Create and setup character
                await setupCharacter()
            }
            .task {
                // Update loop for character movement
                await characterUpdateLoop()
            }
            
            // UI Controls overlay
            VStack {
                Spacer()
                
                CharacterControlsView(controller: characterController)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .padding()
            }
        }
    }
    
    private func setupLighting(in content: RealityViewContent) {
        let directionalLight = DirectionalLight()
        directionalLight.light.intensity = 5000
        directionalLight.position = [0, 2, 0]
        directionalLight.look(at: [0, 0, 0], from: directionalLight.position, relativeTo: nil)
        content.add(directionalLight)
    }
    
    private func setupCharacter() async {
        // Create character entity with CharacterControllerComponent
        let character = createCharacterEntity()
        
        // Position character 1 meter in front of user at floor level
        character.position = [0, 0, -1.5]
        
        // Update controller's character reference
        await MainActor.run {
            characterController.characterEntity = character
        }
        
        // Add to scene
        rootEntity.addChild(character)
        
        print("✅ Character created and added to scene")
    }
    
    private func createCharacterEntity() -> Entity {
        let character = Entity()
        character.name = "WalkingCharacter"
        
        // Create visual representation - a simple humanoid
        let body = createHumanoidBody()
        character.addChild(body)
        
        // Add CharacterControllerComponent for movement
        var characterController = CharacterControllerComponent()
        characterController.height = 1.8  // 1.8m tall human
        characterController.radius = 0.3  // 0.3m wide capsule
        characterController.skinWidth = 0.02  // 2cm tolerance
        characterController.slopeLimit = .pi / 4  // Can climb 45° slopes
        characterController.stepLimit = 0.3  // Can step over 30cm obstacles
        character.components.set(characterController)
        
        print("📦 CharacterControllerComponent configured:")
        print("   Height: \(characterController.height)m")
        print("   Radius: \(characterController.radius)m")
        print("   Slope limit: \(characterController.slopeLimit) rad")
        
        return character
    }
    
    private func createHumanoidBody() -> Entity {
        let humanoid = Entity()
        
        // Body - blue box
        let body = ModelEntity(
            mesh: .generateBox(size: [0.4, 0.8, 0.25]),
            materials: [SimpleMaterial(color: .systemBlue, isMetallic: false)]
        )
        body.position = [0, 1.0, 0]
        
        // Head - pink sphere
        let head = ModelEntity(
            mesh: .generateSphere(radius: 0.2),
            materials: [SimpleMaterial(color: .systemPink, isMetallic: false)]
        )
        head.position = [0, 1.6, 0]
        
        // Arms - green boxes
        let leftArm = ModelEntity(
            mesh: .generateBox(size: [0.15, 0.6, 0.15]),
            materials: [SimpleMaterial(color: .systemGreen, isMetallic: false)]
        )
        leftArm.position = [-0.35, 1.0, 0]
        
        let rightArm = ModelEntity(
            mesh: .generateBox(size: [0.15, 0.6, 0.15]),
            materials: [SimpleMaterial(color: .systemGreen, isMetallic: false)]
        )
        rightArm.position = [0.35, 1.0, 0]
        
        // Legs - red boxes
        let leftLeg = ModelEntity(
            mesh: .generateBox(size: [0.18, 0.8, 0.18]),
            materials: [SimpleMaterial(color: .systemRed, isMetallic: false)]
        )
        leftLeg.position = [-0.15, 0.4, 0]
        
        let rightLeg = ModelEntity(
            mesh: .generateBox(size: [0.18, 0.8, 0.18]),
            materials: [SimpleMaterial(color: .systemRed, isMetallic: false)]
        )
        rightLeg.position = [0.15, 0.4, 0]
        
        humanoid.addChild(body)
        humanoid.addChild(head)
        humanoid.addChild(leftArm)
        humanoid.addChild(rightArm)
        humanoid.addChild(leftLeg)
        humanoid.addChild(rightLeg)
        
        return humanoid
    }
    
    private func characterUpdateLoop() async {
        // Run at 60 FPS
        while true {
            await MainActor.run {
                characterController.update(deltaTime: 1.0 / 60.0)
            }
            try? await Task.sleep(for: .milliseconds(16))
        }
    }
}

// MARK: - Character Controls UI

struct CharacterControlsView: View {
    @ObservedObject var controller: CharacterMovementController
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Character Controls")
                .font(.title2)
                .bold()
            
            // Movement info
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Speed: \(String(format: "%.2f", controller.currentSpeed)) m/s")
                        .font(.caption)
                        .monospaced()
                    
                    Text(controller.isOnGround ? "✅ On Ground" : "⚠️ In Air")
                        .font(.caption)
                        .foregroundColor(controller.isOnGround ? .green : .orange)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
            Divider()
            
            // Movement buttons
            VStack(spacing: 15) {
                // Forward button
                Button(action: {
                    controller.moveForward()
                }) {
                    Label("Walk Forward", systemImage: "arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                HStack(spacing: 15) {
                    // Turn left
                    Button(action: {
                        controller.turnLeft()
                    }) {
                        Label("Turn Left", systemImage: "arrow.turn.up.left")
                            .padding()
                            .background(.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    // Turn right
                    Button(action: {
                        controller.turnRight()
                    }) {
                        Label("Turn Right", systemImage: "arrow.turn.up.right")
                            .padding()
                            .background(.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                
                // Backward button
                Button(action: {
                    controller.moveBackward()
                }) {
                    Label("Walk Backward", systemImage: "arrow.down")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                // Stop button
                Button(action: {
                    controller.stop()
                }) {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
    }
}

#Preview {
    CharacterMovementView()
        .environment(AppModel())
}
