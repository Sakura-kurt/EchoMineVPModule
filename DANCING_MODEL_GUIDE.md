# Dancing Model Demo - Setup Guide

## What I Created

I've added a new **Dancing Model Demo** to your app that demonstrates RealityKit rigged character animations. 

### New Files:
- `DancingModelView.swift` - The view that displays and controls animated characters

### Modified Files:
- `ContentView.swift` - Added a purple "Dancing Model Demo" button (all existing code preserved)

## How to Use

1. Run the app on Vision Pro or simulator
2. In the main window, you'll see a new purple button: **"Dancing Model Demo"**
3. Tap it to open the dancing character view
4. Use the controls:
   - **Play Dance** - Start/resume animation
   - **Pause** - Pause the animation
   - **Stop** - Stop the animation

## Current State - Placeholder Animation

Right now, the demo shows a **colorful humanoid placeholder** made of basic shapes:
- 🔵 Blue body
- 🩷 Pink head
- 🟢 Green arms
- 🔴 Red legs

The placeholder spins continuously to demonstrate animation.

## How to Add Your Own Rigged Character

To use a real rigged character with dance animations:

### Step 1: Get a Rigged USDZ Model

You need a USDZ file with:
- A 3D character mesh
- Skeleton/rig
- Animation clips (walk, dance, idle, etc.)

**Where to get models:**
- Apple's AR Quick Look Gallery
- Sketchfab (export as USDZ)
- Create in Blender/Maya and export to USDZ
- Use Reality Composer Pro

### Step 2: Add Model to Your Project

1. In Xcode, open the **RealityKitContent** package
2. Drag your `.usdz` or `.reality` file into the package
3. Note the exact filename (e.g., "DancingCharacter.usdz")

### Step 3: Load Your Model in Code

Open `DancingModelView.swift` and find this section (around line 76):

```swift
// Option 1: Load from RealityKitContent bundle
// let entity = try await Entity(named: "YourCharacterModel", in: realityKitContentBundle)
```

Replace `"YourCharacterModel"` with your actual filename (without extension):

```swift
let entity = try await Entity(named: "DancingCharacter", in: realityKitContentBundle)
```

### Step 4: Play Specific Animations

If your model has multiple animations, you can access them by name:

```swift
// List all available animations
for animation in entity.availableAnimations {
    print("Available animation: \(animation.name ?? "unnamed")")
}

// Play a specific animation by name
if let danceAnimation = entity.availableAnimations.first(where: { $0.name == "Dance" }) {
    entity.playAnimation(danceAnimation.repeat())
}
```

## Animation Control Examples

### Play Animation Once
```swift
entity.playAnimation(animationResource)
```

### Loop Animation Forever
```swift
entity.playAnimation(animationResource.repeat())
```

### Loop Animation N Times
```swift
entity.playAnimation(animationResource.repeat(count: 3))
```

### Play Animation with Speed Control
```swift
var controller = entity.playAnimation(animationResource.repeat())
controller.speed = 2.0 // 2x speed
```

### Blend Between Animations
```swift
let walkAnim = entity.availableAnimations.first(where: { $0.name == "Walk" })
let runAnim = entity.availableAnimations.first(where: { $0.name == "Run" })

if let walk = walkAnim, let run = runAnim {
    entity.playAnimation(walk, transitionDuration: 0.5)
    // Later...
    entity.playAnimation(run, transitionDuration: 0.5) // Smooth transition
}
```

## Positioning Your Character

Adjust position, scale, and rotation:

```swift
character.position = [0, 0, -1.5] // x, y, z in meters
character.scale = [1, 1, 1] // Scale multiplier
character.orientation = simd_quatf(angle: .pi/4, axis: [0, 1, 0]) // Rotate 45° on Y axis
```

## Creating Custom Animations in Code

You can create procedural animations:

```swift
// Rotation animation
let rotationAnimation = FromToByAnimation<Transform>(
    name: "spin",
    from: .init(rotation: simd_quatf(angle: 0, axis: [0, 1, 0])),
    to: .init(rotation: simd_quatf(angle: .pi * 2, axis: [0, 1, 0])),
    duration: 2.0,
    bindTarget: .transform
)

if let animation = try? AnimationResource.generate(with: rotationAnimation) {
    entity.playAnimation(animation.repeat())
}

// Position animation (bouncing)
var transform = entity.transform
transform.translation.y += 0.5

let bounce = FromToByAnimation<Transform>(
    name: "bounce",
    from: entity.transform,
    to: transform,
    duration: 0.5,
    bindTarget: .transform
)
```

## Recommended Free Character Models

1. **Mixamo** (mixamo.com)
   - Free rigged characters with hundreds of animations
   - Download as FBX, then convert to USDZ using Reality Converter

2. **Apple's AR Quick Look Gallery**
   - Pre-made USDZ models
   - Already optimized for Apple devices

3. **Sketchfab**
   - Search for "rigged character"
   - Filter by "Downloadable" and "USDZ"

## Converting FBX to USDZ

If you have an FBX model from Mixamo:

1. Download **Reality Converter** (free from Apple)
2. Drag your FBX file into Reality Converter
3. Export as USDZ
4. Add to your Xcode project

## Troubleshooting

### "Failed to load character model"
- Check the filename matches exactly (case-sensitive)
- Make sure the file is in the RealityKitContent package
- Verify the USDZ file is valid

### No animations playing
- Check if `entity.availableAnimations` is empty
- Some models may have animations but they're not named
- Try: `entity.availableAnimations.first?.repeat()`

### Character too big/small
- Adjust the scale: `character.scale = [0.5, 0.5, 0.5]` (half size)

### Character facing wrong direction
- Rotate it: `character.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])` (180° turn)

## Advanced: Controlling Individual Bones

For advanced animation control:

```swift
if let skeleton = entity.components[ModelComponent.self]?.mesh.skeleton {
    // Access individual bones
    for joint in skeleton.joints {
        print("Joint: \(joint.name)")
    }
}
```

## Next Steps

1. **Download a rigged character** from Mixamo or Sketchfab
2. **Convert to USDZ** if needed
3. **Add to RealityKitContent** package
4. **Update the code** to load your model
5. **Test and adjust** position/scale/animations

## Example Character Setup

```swift
private func loadDancingCharacter(into content: RealityViewContent) async {
    do {
        // Load your character
        let character = try await Entity(named: "Robot", in: realityKitContentBundle)
        
        // Position it
        character.position = [0, 0, -2] // 2 meters away
        character.scale = [0.01, 0.01, 0.01] // Scale down if needed
        
        // Find and play dance animation
        if let danceAnim = character.availableAnimations.first(where: { $0.name == "Dance" }) {
            character.playAnimation(danceAnim.repeat())
        } else if let firstAnim = character.availableAnimations.first {
            // Fallback to any available animation
            character.playAnimation(firstAnim.repeat())
        }
        
        dancingEntity = character
        content.add(character)
        
    } catch {
        print("Error: \(error)")
    }
}
```

Happy dancing! 💃🕺
