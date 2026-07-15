import Combine
import RealityKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

private enum FieldGuideMarineLifeRealityHeroScene {
    nonisolated static let sceneRootName = "FieldGuideMarineLifeHeroSceneRoot"
    nonisolated static let modelAnchorName = "FieldGuideMarineLifeHeroModelAnchor"
    nonisolated static let glowShadowName = "FieldGuideMarineLifeHeroGlowShadow"
    nonisolated static let glowDiscsName = "FieldGuideMarineLifeHeroGlowDiscs"
    nonisolated static let glowParticlesName = "FieldGuideMarineLifeHeroGlowParticles"
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

    weak var modelAnchor: Entity?
    var modelBasePosition: SIMD3<Float> = .zero
    var modelBobElapsed: TimeInterval = 0

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

    func advanceModelBob(deltaTime: TimeInterval) {
        modelBobElapsed += deltaTime
        applyModelTransform()
    }

    func applyModelTransform() {
        guard let modelAnchor else { return }
        let bob = FieldGuideMarineLifeHeroModelMotionPresentation.bobOffset(elapsed: modelBobElapsed)
        modelAnchor.position = [
            modelBasePosition.x,
            modelBasePosition.y + bob,
            modelBasePosition.z,
        ]
        modelAnchor.transform.rotation = simd_quatf(
            angle: totalYawRadians,
            axis: [0, 1, 0]
        )
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
/// Hosted in a non-AR **`ARView`** with a clear environment so the page chrome shows
/// through (no teal wash / backplate behind the mesh).
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
            FieldGuideMarineLifeClearARHeroRepresentable(
                configuration: configuration,
                interactionState: interactionState
            )

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
}

#if canImport(UIKit)
/// Non-AR RealityKit canvas with a transparent clear color (SwiftUI page shows through).
private struct FieldGuideMarineLifeClearARHeroRepresentable: UIViewRepresentable {
    let configuration: FieldGuideMarineLifeHeroSceneConfiguration
    let interactionState: FieldGuideMarineLifeHeroInteractionState

    func makeCoordinator() -> Coordinator {
        Coordinator(configuration: configuration, interactionState: interactionState)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(
            frame: .zero,
            cameraMode: .nonAR,
            automaticallyConfigureSession: false
        )
        arView.environment.background = .color(.clear)
        arView.backgroundColor = .clear
        arView.isOpaque = false
        context.coordinator.attach(to: arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.configuration = configuration
        context.coordinator.interactionState = interactionState
        context.coordinator.reloadIfNeeded(in: uiView)
    }

    @MainActor
    final class Coordinator {
        var configuration: FieldGuideMarineLifeHeroSceneConfiguration
        var interactionState: FieldGuideMarineLifeHeroInteractionState
        private var loadedResourceName: String?
        private var updateSubscription: (any Cancellable)?

        init(
            configuration: FieldGuideMarineLifeHeroSceneConfiguration,
            interactionState: FieldGuideMarineLifeHeroInteractionState
        ) {
            self.configuration = configuration
            self.interactionState = interactionState
        }

        func attach(to arView: ARView) {
            reloadIfNeeded(in: arView)
        }

        func reloadIfNeeded(in arView: ARView) {
            let resourceName = configuration.modelResourceName
            guard loadedResourceName != resourceName else { return }
            loadedResourceName = resourceName
            updateSubscription?.cancel()
            updateSubscription = nil
            for anchor in arView.scene.anchors {
                arView.scene.removeAnchor(anchor)
            }
            Task { @MainActor in
                await self.loadScene(into: arView)
            }
        }

        private func loadScene(into arView: ARView) async {
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

            // Bail if the user switched species while we were loading.
            guard loadedResourceName == configuration.modelResourceName else { return }

            let bounds = loadedEntity.visualBounds(relativeTo: nil)
            let extent = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
            let scale = extent > 0 ? configuration.fitExtent / extent : 1

            let sceneRoot = AnchorEntity(world: .zero)
            sceneRoot.name = FieldGuideMarineLifeRealityHeroScene.sceneRootName

            let modelAnchor = Entity()
            modelAnchor.name = FieldGuideMarineLifeRealityHeroScene.modelAnchorName
            fitModelEntity(loadedEntity, bounds: bounds, scale: scale)
            modelAnchor.addChild(loadedEntity)

            // Glow stays a sibling of the model anchor so yaw spin does not orbit the plate/particles.
            let glowShadow = await makeGlowShadowEntity(
                modelPosition: loadedEntity.position,
                modelExtentY: bounds.extents.y,
                modelScale: scale
            )
            sceneRoot.addChild(glowShadow)
            sceneRoot.addChild(modelAnchor)

            let keyLight = DirectionalLight()
            keyLight.light.intensity = 2_800
            keyLight.light.color = .white
            keyLight.orientation = simd_quatf(angle: -.pi / 4, axis: [1, 0.35, 0])
            keyLight.position = [0.4, 0.8, 0.65]
            sceneRoot.addChild(keyLight)

            let fillLight = DirectionalLight()
            fillLight.light.intensity = 1_100
            fillLight.light.color = UIColor(red: 0.78, green: 0.88, blue: 1.0, alpha: 1.0)
            fillLight.orientation = simd_quatf(angle: .pi / 3, axis: [-0.6, -1, 0.2])
            fillLight.position = [-0.55, 0.15, -0.45]
            sceneRoot.addChild(fillLight)

            for anchor in arView.scene.anchors {
                arView.scene.removeAnchor(anchor)
            }
            arView.scene.addAnchor(sceneRoot)
            interactionState.modelAnchor = modelAnchor
            interactionState.modelBasePosition = modelAnchor.position
            interactionState.modelBobElapsed = 0
            interactionState.applyModelTransform()

            updateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) {
                @MainActor [weak self] event in
                guard let self else { return }
                self.interactionState.advanceAutoRotation(deltaTime: event.deltaTime)
                self.interactionState.advanceModelBob(deltaTime: event.deltaTime)
                self.interactionState.advanceGlowPulse(deltaTime: event.deltaTime)
            }
        }

        private func fitModelEntity(_ entity: Entity, bounds: BoundingBox, scale: Float) {
            guard scale > 0 else { return }
            entity.scale = SIMD3(repeating: scale)
            entity.position = -bounds.center * scale
            entity.position.z += configuration.modelForwardOffset
            entity.position.y += configuration.modelVerticalOffset
        }

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

        private func makeGlowParticleEntity(baseRadius: Float) -> Entity {
            let entity = Entity()
            entity.name = FieldGuideMarineLifeRealityHeroScene.glowParticlesName

            var particles = ParticleEmitterComponent.Presets.magic
            particles.emitterShape = .cylinder
            particles.birthLocation = .volume
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

            let start = UIColor(red: 0.45, green: 0.82, blue: 1.0, alpha: 0.95)
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

            entity.components.set(particles)
            return entity
        }

        private func makeUnlitMaterial(
            rgb: (red: Float, green: Float, blue: Float),
            intensity: Float,
            additive: Bool
        ) async -> UnlitMaterial {
            let clamped = Swift.min(Swift.max(intensity, 0), 1)
            let tint = UIColor(
                red: CGFloat(rgb.red * clamped),
                green: CGFloat(rgb.green * clamped),
                blue: CGFloat(rgb.blue * clamped),
                alpha: 1.0
            )

            if additive {
                var descriptor = UnlitMaterial.Program.Descriptor()
                descriptor.blendMode = .add
                let program = await UnlitMaterial.Program(descriptor: descriptor)
                var material = UnlitMaterial(program: program)
                material.color = .init(tint: tint)
                return material
            }

            return UnlitMaterial(color: tint)
        }

        private func makeAccentGlowMaterial(intensity: Float) async -> UnlitMaterial {
            let rgb = FieldGuideMarineLifeHeroGlowPresentation.tintRGB(intensity: intensity)
            return await makeUnlitMaterial(rgb: rgb, intensity: 1, additive: true)
        }
    }
}
#else
private struct FieldGuideMarineLifeClearARHeroRepresentable: View {
    let configuration: FieldGuideMarineLifeHeroSceneConfiguration
    let interactionState: FieldGuideMarineLifeHeroInteractionState

    var body: some View {
        Color.clear
            .accessibilityHidden(true)
    }
}
#endif
