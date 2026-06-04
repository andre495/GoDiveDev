import RealityKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

private enum FieldGuideMarineLifeRealityHeroScene {
    nonisolated static let modelAnchorName = "FieldGuideMarineLifeHeroModelAnchor"
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

    var totalYawRadians: Float {
        initialYawRadians + autoYawRadians + committedYawRadians + dragYawRadians
    }
}

/// Interactive RealityKit hero for Field Guide species with a bundled USDZ model.
struct FieldGuideMarineLifeRealityHeroView: View {
    let configuration: FieldGuideMarineLifeHeroSceneConfiguration
    let height: CGFloat

    @State private var interactionState: FieldGuideMarineLifeHeroInteractionState

    init(configuration: FieldGuideMarineLifeHeroSceneConfiguration, height: CGFloat) {
        self.configuration = configuration
        self.height = height
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
            RealityView { content in
                await loadScene(into: &content)
            }

            if configuration.allowsDragRotation {
                Color.clear
                    .contentShape(Rectangle())
                    .highPriorityGesture(dragGesture)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
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

        let anchor = AnchorEntity()
        anchor.name = FieldGuideMarineLifeRealityHeroScene.modelAnchorName
        fitModelEntity(loadedEntity)
        anchor.addChild(loadedEntity)
        content.add(anchor)

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

        let modelAnchor = anchor
        _ = content.subscribe(to: SceneEvents.Update.self) { @MainActor event in
            interactionState.advanceAutoRotation(deltaTime: event.deltaTime)
            modelAnchor.transform.rotation = simd_quatf(
                angle: interactionState.totalYawRadians,
                axis: [0, 1, 0]
            )
        }
    }

    @MainActor
    private func fitModelEntity(_ entity: Entity) {
        let bounds = entity.visualBounds(relativeTo: nil)
        let extent = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
        guard extent > 0 else { return }

        let scale = configuration.fitExtent / extent
        entity.scale = SIMD3(repeating: scale)
        entity.position = -bounds.center * scale
        entity.position.z += configuration.modelForwardOffset
        entity.position.y += configuration.modelVerticalOffset
    }
}
