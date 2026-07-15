import RealityKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

private enum FieldGuideMarineLifeRealityHeroScene {
    nonisolated static let modelAnchorName = "FieldGuideMarineLifeHeroModelAnchor"
    nonisolated static let glowShadowName = "FieldGuideMarineLifeHeroGlowShadow"
    nonisolated static let glowDiscsName = "FieldGuideMarineLifeHeroGlowDiscs"
    nonisolated static let glowParticlesName = "FieldGuideMarineLifeHeroGlowParticles"
    nonisolated static let backdropName = "FieldGuideMarineLifeHeroBackdrop"
}

/// Shared drag + auto-spin state read every frame from a RealityKit update subscription.
@MainActor
private final class FieldGuideMarineLifeHeroInteractionState {
    let initialYawRadians: Float
    let autoRotateSpeedRadiansPerSecond: Float
    let autoSpinPauseAfterDragSeconds: TimeInterval

    var committedYawRadians: Float = 0
    var dragYawRadians: Float = 0
    var isDragging = false
    var autoSpinPausedUntil: Date?
    private var autoYawRadians: Float = 0

    weak var glowDiscsEntity: Entity?
    var glowPulseElapsed: TimeInterval = 0
    var glowBasePosition: SIMD3<Float> = .zero

    init(
        initialYawRadians: Float,
        autoRotateSpeedRadiansPerSecond: Float,
        autoSpinPauseAfterDragSeconds: TimeInterval
    ) {
        self.initialYawRadians = initialYawRadians
        self.autoRotateSpeedRadiansPerSecond = autoRotateSpeedRadiansPerSecond
        self.autoSpinPauseAfterDragSeconds = autoSpinPauseAfterDragSeconds
    }

    func noteDragChanged() {
        isDragging = true
    }

    func noteDragEnded(now: Date = Date()) {
        isDragging = false
        autoSpinPausedUntil = now.addingTimeInterval(autoSpinPauseAfterDragSeconds)
    }

    func advanceAutoRotation(deltaTime: TimeInterval, now: Date = Date()) {
        guard FieldGuideMarineLifeHeroPresentation.shouldAdvanceAutoSpin(
            autoRotateSpeedRadiansPerSecond: autoRotateSpeedRadiansPerSecond,
            isDragging: isDragging,
            autoSpinPausedUntil: autoSpinPausedUntil,
            now: now
        ) else {
            return
        }
        autoYawRadians += autoRotateSpeedRadiansPerSecond * Float(deltaTime)
    }

    func advanceGlowPulse(deltaTime: TimeInterval) {
        glowPulseElapsed += deltaTime
        guard let glowDiscsEntity else { return }
        let scale = FieldGuideMarineLifeHeroGlowPresentation.pulseScale(elapsed: glowPulseElapsed)
        let lift = FieldGuideMarineLifeHeroGlowPresentation.pulseVerticalOffset(elapsed: glowPulseElapsed)
        glowDiscsEntity.scale = [scale, 1, scale]
        glowDiscsEntity.position = [
            glowBasePosition.x,
            glowBasePosition.y + lift,
            glowBasePosition.z,
        ]
    }

    var totalYawRadians: Float {
        initialYawRadians + autoYawRadians + committedYawRadians + dragYawRadians
    }
}

/// Interactive RealityKit hero for Field Guide species with a bundled USDZ model.
struct FieldGuideMarineLifeRealityHeroView: View {
    let configuration: FieldGuideMarineLifeHeroSceneConfiguration

    @State private var interactionState: FieldGuideMarineLifeHeroInteractionState

    init(configuration: FieldGuideMarineLifeHeroSceneConfiguration) {
        self.configuration = configuration
        _interactionState = State(
            initialValue: FieldGuideMarineLifeHeroInteractionState(
                initialYawRadians: configuration.initialYawRadians,
                autoRotateSpeedRadiansPerSecond: configuration.autoRotateSpeedRadiansPerSecond,
                autoSpinPauseAfterDragSeconds: configuration.autoSpinPauseAfterDragSeconds
            )
        )
    }

    var body: some View {
        ZStack {
            FieldGuideMarineLifeHeroBackdropGlowView()

            RealityView { content in
                await loadScene(into: &content)
            }

            if configuration.allowsDragRotation {
                Color.clear
                    .contentShape(Rectangle())
                    .highPriorityGesture(dragGesture)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .accessibilityLabel("3D model")
        .accessibilityHint(
            configuration.allowsDragRotation
                ? "Drag horizontally to rotate the model"
                : "Animated 3D species model"
        )
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                interactionState.noteDragChanged()
                interactionState.dragYawRadians = Float(value.translation.width) * 0.015
            }
            .onEnded { _ in
                interactionState.committedYawRadians += interactionState.dragYawRadians
                interactionState.dragYawRadians = 0
                interactionState.noteDragEnded()
            }
    }

    @MainActor
    private func loadScene(into content: inout RealityViewCameraContent) async {
        content.camera = .virtual

        guard let url = FieldGuideMarineLifeHeroPresentation.bundledModelURL(
            resourceName: configuration.modelResourceName
        ) else {
            #if DEBUG
            print(
                "GoDive: Marine life USDZ missing for \(configuration.modelResourceName). " +
                "Expected Resources/MarineLife3D/\(configuration.modelResourceName).usdz in app bundle."
            )
            #endif
            return
        }

        guard let loadedEntity = try? await Entity(contentsOf: url) else {
            #if DEBUG
            print("GoDive: Failed to load marine life USDZ at \(url.path)")
            #endif
            return
        }

        let bounds = loadedEntity.visualBounds(relativeTo: nil)
        let extent = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
        let scale = extent > 0 ? configuration.fitExtent / extent : 1

        // Cool atmospheric backplate (virtual camera is opaque — SwiftUI alone won't show through).
        content.add(await makeSceneBackdropEntity())

        let modelAnchor = AnchorEntity()
        modelAnchor.name = FieldGuideMarineLifeRealityHeroScene.modelAnchorName
        fitModelEntity(loadedEntity, bounds: bounds, scale: scale)

        // Glow stays a sibling of the model anchor so yaw spin does not orbit the plate/particles.
        let glowShadow = await makeGlowShadowEntity(
            modelPosition: loadedEntity.position,
            modelExtentY: bounds.extents.y,
            modelScale: scale
        )
        content.add(glowShadow)
        modelAnchor.addChild(loadedEntity)
        content.add(modelAnchor)

        let keyLight = DirectionalLight()
        keyLight.light.intensity = 2_800
        keyLight.light.color = .white
        keyLight.orientation = simd_quatf(angle: -.pi / 4, axis: [1, 0.35, 0])
        keyLight.position = [0.4, 0.8, 0.65]
        content.add(keyLight)

        let fillLight = DirectionalLight()
        fillLight.light.intensity = 1_100
        #if canImport(UIKit)
        fillLight.light.color = UIColor(red: 0.78, green: 0.88, blue: 1.0, alpha: 1.0)
        #else
        fillLight.light.color = .white
        #endif
        fillLight.orientation = simd_quatf(angle: .pi / 3, axis: [-0.6, -1, 0.2])
        fillLight.position = [-0.55, 0.15, -0.45]
        content.add(fillLight)

        _ = content.subscribe(to: SceneEvents.Update.self) { @MainActor event in
            interactionState.advanceAutoRotation(deltaTime: event.deltaTime)
            interactionState.advanceGlowPulse(deltaTime: event.deltaTime)
            modelAnchor.transform.rotation = simd_quatf(
                angle: interactionState.totalYawRadians,
                axis: [0, 1, 0]
            )
        }
    }

    @MainActor
    private func fitModelEntity(_ entity: Entity, bounds: BoundingBox, scale: Float) {
        guard scale > 0 else { return }
        entity.scale = SIMD3(repeating: scale)
        entity.position = -bounds.center * scale
        entity.position.z += configuration.modelForwardOffset
        entity.position.y += configuration.modelVerticalOffset
    }

    @MainActor
    private func makeGlowShadowEntity(
        modelPosition: SIMD3<Float>,
        modelExtentY: Float,
        modelScale: Float
    ) async -> Entity {
        let root = Entity()
        root.name = FieldGuideMarineLifeRealityHeroScene.glowShadowName

        let baseRadius = FieldGuideMarineLifeHeroGlowPresentation.baseRadius(
            fitExtent: configuration.fitExtent
        )
        let glowY = FieldGuideMarineLifeHeroGlowPresentation.discY(
            modelPositionY: modelPosition.y,
            modelExtentY: modelExtentY,
            modelScale: modelScale
        )
        // Centered on the yaw axis (model-anchor origin), not the mesh’s forward/lateral offset.
        let glowPosition = FieldGuideMarineLifeHeroGlowPresentation.discPositionUnderSpinAxis(
            glowY: glowY
        )

        let discs = Entity()
        discs.name = FieldGuideMarineLifeRealityHeroScene.glowDiscsName
        discs.position = glowPosition
        for layer in FieldGuideMarineLifeHeroGlowPresentation.layers {
            let material = await makeAccentGlowMaterial(intensity: layer.intensity)
            let disc = ModelEntity(
                mesh: .generateCylinder(
                    height: FieldGuideMarineLifeHeroGlowPresentation.discHeight,
                    radius: baseRadius * layer.radiusScale
                ),
                materials: [material]
            )
            discs.addChild(disc)
        }
        root.addChild(discs)

        let particles = makeGlowParticleEntity(baseRadius: baseRadius)
        particles.position = glowPosition
        root.addChild(particles)

        interactionState.glowDiscsEntity = discs
        interactionState.glowBasePosition = glowPosition
        interactionState.glowPulseElapsed = 0

        return root
    }

    @MainActor
    private func makeGlowParticleEntity(baseRadius: Float) -> Entity {
        let entity = Entity()
        entity.name = FieldGuideMarineLifeRealityHeroScene.glowParticlesName

        var particles = ParticleEmitterComponent.Presets.magic
        particles.emitterShape = .cylinder
        particles.birthLocation = .volume
        // World **+Y** so spray stays upward while the model/orbits spin.
        particles.birthDirection = .world
        particles.emissionDirection = FieldGuideMarineLifeHeroGlowPresentation.particleEmissionDirection
        particles.particlesInheritTransform = false
        particles.fieldSimulationSpace = .global
        particles.emitterShapeSize = FieldGuideMarineLifeHeroGlowPresentation.particleEmitterShapeSize(
            baseRadius: baseRadius
        )
        particles.speed = FieldGuideMarineLifeHeroGlowPresentation.particleSpeed
        particles.speedVariation = FieldGuideMarineLifeHeroGlowPresentation.particleSpeedVariation
        particles.mainEmitter.birthRate = FieldGuideMarineLifeHeroGlowPresentation.particleBirthRate
        particles.mainEmitter.size = FieldGuideMarineLifeHeroGlowPresentation.particleSize
        particles.mainEmitter.lifeSpan = FieldGuideMarineLifeHeroGlowPresentation.particleLifeSpan
        particles.mainEmitter.spreadingAngle =
            FieldGuideMarineLifeHeroGlowPresentation.particleSpreadingAngle

        #if canImport(UIKit)
        let start = UIColor(
            red: 0.45,
            green: 0.82,
            blue: 1.0,
            alpha: 0.95
        )
        let end = UIColor(
            red: CGFloat(FieldGuideMarineLifeHeroGlowPresentation.accentRed),
            green: CGFloat(FieldGuideMarineLifeHeroGlowPresentation.accentGreen),
            blue: CGFloat(FieldGuideMarineLifeHeroGlowPresentation.accentBlue),
            alpha: 0.0
        )
        particles.mainEmitter.color = .evolving(
            start: .single(start),
            end: .single(end)
        )
        #endif

        entity.components.set(particles)
        return entity
    }

    @MainActor
    private func makeSceneBackdropEntity() async -> Entity {
        let root = Entity()
        root.name = FieldGuideMarineLifeRealityHeroScene.backdropName

        let plateMaterial = await makeUnlitMaterial(
            rgb: FieldGuideMarineLifeHeroBackdropPresentation.scenePlateRGB,
            intensity: 1,
            additive: false
        )
        let plate = ModelEntity(
            mesh: .generatePlane(
                width: FieldGuideMarineLifeHeroBackdropPresentation.scenePlaneWidth,
                height: FieldGuideMarineLifeHeroBackdropPresentation.scenePlaneHeight
            ),
            materials: [plateMaterial]
        )
        plate.position = [
            0,
            FieldGuideMarineLifeHeroBackdropPresentation.scenePlaneY,
            FieldGuideMarineLifeHeroBackdropPresentation.scenePlaneZ,
        ]
        root.addChild(plate)

        return root
    }

    @MainActor
    private func makeUnlitMaterial(
        rgb: (red: Float, green: Float, blue: Float),
        intensity: Float,
        additive: Bool
    ) async -> UnlitMaterial {
        let clamped = Swift.min(Swift.max(intensity, 0), 1)
        #if canImport(UIKit)
        let tint = UIColor(
            red: CGFloat(rgb.red * clamped),
            green: CGFloat(rgb.green * clamped),
            blue: CGFloat(rgb.blue * clamped),
            alpha: 1.0
        )
        #else
        let tint = RealityKit.Material.Color(
            red: Double(rgb.red * clamped),
            green: Double(rgb.green * clamped),
            blue: Double(rgb.blue * clamped),
            alpha: 1.0
        )
        #endif

        if additive {
            var descriptor = UnlitMaterial.Program.Descriptor()
            descriptor.blendMode = .add
            let program = await UnlitMaterial.Program(descriptor: descriptor)
            var material = UnlitMaterial(program: program)
            material.color = .init(tint: tint)
            return material
        }

        let material = UnlitMaterial(color: tint)
        return material
    }

    @MainActor
    private func makeAccentGlowMaterial(intensity: Float) async -> UnlitMaterial {
        let rgb = FieldGuideMarineLifeHeroGlowPresentation.tintRGB(intensity: intensity)
        return await makeUnlitMaterial(rgb: rgb, intensity: 1, additive: true)
    }
}

/// Cool teal atmospheric wash behind RealityKit marine-life heroes.
private struct FieldGuideMarineLifeHeroBackdropGlowView: View {
    var body: some View {
        LinearGradient(
            colors: [
                FieldGuideMarineLifeHeroBackdropPresentation.color(
                    FieldGuideMarineLifeHeroBackdropPresentation.baseTop
                ),
                FieldGuideMarineLifeHeroBackdropPresentation.color(
                    FieldGuideMarineLifeHeroBackdropPresentation.baseMid
                ),
                FieldGuideMarineLifeHeroBackdropPresentation.color(
                    FieldGuideMarineLifeHeroBackdropPresentation.baseBottom
                ),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
