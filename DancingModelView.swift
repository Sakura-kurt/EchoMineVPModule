//
//  DancingModelView.swift
//  ARCollision
//
//  Created on 1/21/26.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct DancingModelView: View {
    @State private var dancingEntity: Entity?
    @State private var isPlaying = false
    @State private var errorMessage: String?
    @State private var rootEntity = Entity() // Root entity to hold our character
    
    var body: some View {
        VStack {
            RealityView { content in
                // Add lighting for better visibility
                setupLighting(in: content)
                
                // Add the root entity that will contain our character
                content.add(rootEntity)
            }
            .task {
                // Load the dancing character when the view appears
                if dancingEntity == nil {
                    await loadDancingCharacter()
                }
            }
            
            VStack(spacing: 20) {
                Text("Dancing Character Demo")
                    .font(.title)
                    .padding()
                
                if let error = errorMessage {
                    Text("⚠️ \(error)")
                        .foregroundColor(.red)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
                
                HStack(spacing: 20) {
                    Button(action: {
                        playAnimation()
                    }) {
                        Label("Play Dance", systemImage: "play.fill")
                            .padding()
                            .background(.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        pauseAnimation()
                    }) {
                        Label("Pause", systemImage: "pause.fill")
                            .padding()
                            .background(.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        stopAnimation()
                    }) {
                        Label("Stop", systemImage: "stop.fill")
                            .padding()
                            .background(.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding()
                
                Text(isPlaying ? "🎵 Dancing..." : "⏸️ Stopped")
                    .font(.headline)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
            }
            .padding()
        }
    }
    
    // MARK: - Setup Lighting
    
    private func setupLighting(in content: RealityViewContent) {
        // Add directional light
        let directionalLight = DirectionalLight()
        directionalLight.light.intensity = 5000
        directionalLight.position = [0, 2, 0]
        directionalLight.look(at: [0, 0, 0], from: directionalLight.position, relativeTo: nil)
        content.add(directionalLight)
        
        // Add ambient light
        let ambientLight = PointLight()
        ambientLight.light.intensity = 3000
        ambientLight.position = [0, 1, 1]
        content.add(ambientLight)
    }
    
    // MARK: - Load Character
    
    private func loadDancingCharacter() async {
        do {
            // Try to load a character model from RealityKitContent
            // Note: You'll need to add your own USDZ model with animations
            
            // Option 1: Load from RealityKitContent bundle
            // let entity = try await Entity(named: "YourCharacterModel", in: realityKitContentBundle)
            
            // Option 2: Create a simple humanoid placeholder
            let character = createPlaceholderCharacter()
            
            character.position = [0, 0, -1.5] // 1.5 meters in front
            character.scale = [1, 1, 1]
            
            // Add animation if available
            if let animationResource = character.availableAnimations.first {
                character.playAnimation(animationResource.repeat())
            }
            
            dancingEntity = character
            rootEntity.addChild(character)
            
            print("✅ Character loaded successfully")
            
        } catch {
            print("❌ Failed to load character: \(error)")
            await MainActor.run {
                errorMessage = "Failed to load character model. Please add a rigged USDZ model to your project."
            }
            
            // Create a fallback dancing cube
            let fallbackEntity = createDancingCube()
            dancingEntity = fallbackEntity
            rootEntity.addChild(fallbackEntity)
        }
    }
    
    // MARK: - Create Placeholder Character
    
    private func createPlaceholderCharacter() -> Entity {
        let character = Entity()
        
        // Create a simple humanoid shape using primitives
        // Body
        let body = ModelEntity(
            mesh: .generateBox(size: [0.3, 0.6, 0.2]),
            materials: [SimpleMaterial(color: .systemBlue, isMetallic: false)]
        )
        body.position = [0, 0.8, 0]
        
        // Head
        let head = ModelEntity(
            mesh: .generateSphere(radius: 0.15),
            materials: [SimpleMaterial(color: .systemPink, isMetallic: false)]
        )
        head.position = [0, 1.3, 0]
        
        // Left arm
        let leftArm = ModelEntity(
            mesh: .generateBox(size: [0.1, 0.5, 0.1]),
            materials: [SimpleMaterial(color: .systemGreen, isMetallic: false)]
        )
        leftArm.position = [-0.25, 0.8, 0]
        
        // Right arm
        let rightArm = ModelEntity(
            mesh: .generateBox(size: [0.1, 0.5, 0.1]),
            materials: [SimpleMaterial(color: .systemGreen, isMetallic: false)]
        )
        rightArm.position = [0.25, 0.8, 0]
        
        // Left leg
        let leftLeg = ModelEntity(
            mesh: .generateBox(size: [0.12, 0.6, 0.12]),
            materials: [SimpleMaterial(color: .systemRed, isMetallic: false)]
        )
        leftLeg.position = [-0.1, 0.2, 0]
        
        // Right leg
        let rightLeg = ModelEntity(
            mesh: .generateBox(size: [0.12, 0.6, 0.12]),
            materials: [SimpleMaterial(color: .systemRed, isMetallic: false)]
        )
        rightLeg.position = [0.1, 0.2, 0]
        
        // Add all parts to character
        character.addChild(body)
        character.addChild(head)
        character.addChild(leftArm)
        character.addChild(rightArm)
        character.addChild(leftLeg)
        character.addChild(rightLeg)
        
        // Add a simple rotation animation
        let rotationAnimation = FromToByAnimation<Transform>(
            name: "spin",
            from: .init(rotation: simd_quatf(angle: 0, axis: [0, 1, 0])),
            to: .init(rotation: simd_quatf(angle: .pi * 2, axis: [0, 1, 0])),
            duration: 2.0,
            bindTarget: .transform
        )
        
        if let animation = try? AnimationResource.generate(with: rotationAnimation) {
            character.playAnimation(animation.repeat())
        }
        
        return character
    }
    
    // MARK: - Create Dancing Cube (Fallback)
    
    private func createDancingCube() -> ModelEntity {
        let cube = ModelEntity(
            mesh: .generateBox(size: 0.3),
            materials: [SimpleMaterial(color: .systemPurple, isMetallic: true)]
        )
        
        cube.position = [0, 1.5, -1.5]
        
        // Create a bouncing and spinning animation
        var transform = cube.transform
        transform.translation.y += 0.3
        
        let bounceUp = FromToByAnimation<Transform>(
            name: "bounceUp",
            from: cube.transform,
            to: transform,
            duration: 0.5,
            bindTarget: .transform
        )
        
        let bounceDown = FromToByAnimation<Transform>(
            name: "bounceDown",
            from: transform,
            to: cube.transform,
            duration: 0.5,
            bindTarget: .transform
        )
        
        // Rotation animation
        let rotationAnimation = FromToByAnimation<Transform>(
            name: "spin",
            from: .init(rotation: simd_quatf(angle: 0, axis: [0, 1, 0])),
            to: .init(rotation: simd_quatf(angle: .pi * 2, axis: [0, 1, 0])),
            duration: 1.0,
            bindTarget: .transform
        )
        
        if let bounce = try? AnimationResource.generate(with: bounceUp),
           let bounceBack = try? AnimationResource.generate(with: bounceDown),
           let spin = try? AnimationResource.generate(with: rotationAnimation) {
            
            let sequence = try? AnimationResource.sequence(with: [bounce, bounceBack])
            if let sequence = sequence {
                cube.playAnimation(sequence.repeat())
            }
            cube.playAnimation(spin.repeat())
        }
        
        return cube
    }
    
    // MARK: - Animation Controls
    
    private func playAnimation() {
        guard let entity = dancingEntity else { return }
        
        // Resume or start animation
        if let animation = entity.availableAnimations.first {
            entity.playAnimation(animation.repeat())
            isPlaying = true
            print("▶️ Playing animation")
        } else {
            // If no animations available, create a simple rotation
            let rotationAnimation = FromToByAnimation<Transform>(
                name: "dance",
                from: .init(rotation: simd_quatf(angle: 0, axis: [0, 1, 0])),
                to: .init(rotation: simd_quatf(angle: .pi * 2, axis: [0, 1, 0])),
                duration: 2.0,
                bindTarget: .transform
            )
            
            if let animation = try? AnimationResource.generate(with: rotationAnimation) {
                entity.playAnimation(animation.repeat())
                isPlaying = true
            }
        }
    }
    
    private func pauseAnimation() {
        guard let entity = dancingEntity else { return }
        entity.stopAllAnimations()
        isPlaying = false
        print("⏸️ Paused animation")
    }
    
    private func stopAnimation() {
        guard let entity = dancingEntity else { return }
        entity.stopAllAnimations()
        isPlaying = false
        print("⏹️ Stopped animation")
    }
}

#Preview {
    DancingModelView()
}
