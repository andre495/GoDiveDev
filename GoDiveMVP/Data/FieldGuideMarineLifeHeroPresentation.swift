import Foundation

/// Bundled RealityKit hero configuration for a catalog species detail page.
struct FieldGuideMarineLifeHeroSceneConfiguration: Equatable, Sendable {
    /// USDZ resource name in the app bundle (no extension).
    let modelResourceName: String
    /// Longest axis of the model is scaled to this many scene units after load.
    let fitExtent: Float
    /// Nudge toward the virtual camera after centering (negative = closer).
    let modelForwardOffset: Float
    /// Nudge down (+Y up in scene space; negative lowers the model on screen).
    let modelVerticalOffset: Float
    /// Starting yaw (radians) applied before drag / auto-rotate.
    let initialYawRadians: Float
    /// Idle spin speed; **`0`** disables auto-rotation.
    let autoRotateSpeedRadiansPerSecond: Float
    /// Auto-spin stays off this long after the user finishes a drag.
    let autoSpinPauseAfterDragSeconds: TimeInterval
    /// When **`true`**, horizontal drag orbits the model on the Y axis.
    let allowsDragRotation: Bool

    /// Explicit **nonisolated** equality for Swift 6 checks from nonisolated contexts.
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.modelResourceName == rhs.modelResourceName
            && lhs.fitExtent == rhs.fitExtent
            && lhs.modelForwardOffset == rhs.modelForwardOffset
            && lhs.modelVerticalOffset == rhs.modelVerticalOffset
            && lhs.initialYawRadians == rhs.initialYawRadians
            && lhs.autoRotateSpeedRadiansPerSecond == rhs.autoRotateSpeedRadiansPerSecond
            && lhs.autoSpinPauseAfterDragSeconds == rhs.autoSpinPauseAfterDragSeconds
            && lhs.allowsDragRotation == rhs.allowsDragRotation
    }

    nonisolated static let frenchAngelfish = FieldGuideMarineLifeHeroSceneConfiguration(
        modelResourceName: "FrenchAngelfish",
        fitExtent: 0.48,
        modelForwardOffset: -0.08,
        modelVerticalOffset: -0.09,
        initialYawRadians: -.pi / 5,
        autoRotateSpeedRadiansPerSecond: 0.225,
        autoSpinPauseAfterDragSeconds: 15,
        allowsDragRotation: true
    )
}

/// Resolves species detail hero content (3D model, remote image, or placeholder).
enum FieldGuideMarineLifeHeroPresentation {

    enum HeroKind: Equatable, Sendable {
        case model3D(FieldGuideMarineLifeHeroSceneConfiguration)
        case bundledPhoto(URL)
        case remoteImage(URL)
        case placeholder

        /// Explicit **nonisolated** equality for Swift Testing **`#expect`** (Swift 6).
        nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.placeholder, .placeholder):
                return true
            case (.bundledPhoto(let left), .bundledPhoto(let right)):
                return left == right
            case (.remoteImage(let left), .remoteImage(let right)):
                return left == right
            case (.model3D(let left), .model3D(let right)):
                return left == right
            default:
                return false
            }
        }
    }

    nonisolated static func heroKind(
        featureModelResourceName: String,
        featureImageResourceName: String,
        featureImageURL: String
    ) -> HeroKind {
        let modelName = featureModelResourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !modelName.isEmpty {
            return .model3D(sceneConfiguration(forModelResourceName: modelName))
        }

        let resourceName = featureImageResourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !resourceName.isEmpty,
           let bundledURL = FieldGuideMarineLifeBundledImagePresentation.bundledPhotoURL(
               resourceName: resourceName
           ) {
            return .bundledPhoto(bundledURL)
        }

        let imageURLString = featureImageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: imageURLString), !imageURLString.isEmpty {
            return .remoteImage(url)
        }

        return .placeholder
    }

    nonisolated static func hasCatalogModel(featureModelResourceName: String) -> Bool {
        !featureModelResourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Dataset image only — ignores the bundled 3D model name.
    nonisolated static func catalogImageKind(
        featureImageResourceName: String,
        featureImageURL: String
    ) -> HeroKind? {
        let resourceName = featureImageResourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !resourceName.isEmpty,
           let bundledURL = FieldGuideMarineLifeBundledImagePresentation.bundledPhotoURL(
               resourceName: resourceName
           ) {
            return .bundledPhoto(bundledURL)
        }

        let imageURLString = featureImageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: imageURLString), !imageURLString.isEmpty {
            return .remoteImage(url)
        }

        return nil
    }

    nonisolated static func sceneConfiguration(
        forModelResourceName resourceName: String
    ) -> FieldGuideMarineLifeHeroSceneConfiguration {
        switch resourceName {
        case FieldGuideMarineLifeHeroSceneConfiguration.frenchAngelfish.modelResourceName:
            return .frenchAngelfish
        default:
            return FieldGuideMarineLifeHeroSceneConfiguration(
                modelResourceName: resourceName,
                fitExtent: 0.48,
                modelForwardOffset: -0.08,
                modelVerticalOffset: -0.09,
                initialYawRadians: 0,
                autoRotateSpeedRadiansPerSecond: 0.225,
                autoSpinPauseAfterDragSeconds: 15,
                allowsDragRotation: true
            )
        }
    }

    /// Resolves a bundled USDZ under **`Resources/MarineLife3D/`** or the app bundle root.
    nonisolated static func bundledModelURL(
        resourceName: String,
        bundle: Bundle = .main
    ) -> URL? {
        let subdirectories = [
            "Resources/MarineLife3D",
            "MarineLife3D",
            nil as String?,
        ]
        for subdirectory in subdirectories {
            if let url = bundle.url(
                forResource: resourceName,
                withExtension: "usdz",
                subdirectory: subdirectory
            ) {
                return url
            }
        }
        return nil
    }

    nonisolated static func shouldAdvanceAutoSpin(
        autoRotateSpeedRadiansPerSecond: Float,
        isDragging: Bool,
        autoSpinPausedUntil: Date?,
        now: Date
    ) -> Bool {
        guard autoRotateSpeedRadiansPerSecond != 0 else { return false }
        if isDragging { return false }
        if let autoSpinPausedUntil, now < autoSpinPausedUntil { return false }
        return true
    }
}
