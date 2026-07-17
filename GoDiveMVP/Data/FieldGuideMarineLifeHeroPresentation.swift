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
    /// When **`true`**, the soft accent glow plate + sparkles render under the model.
    /// Species detail heroes use the glow; compact avatars (map Marine Life chips) do not.
    let showsGlow: Bool

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
            && lhs.showsGlow == rhs.showsGlow
    }

    /// Fallback fit when catalog size is missing; also the mid-band visual target.
    nonisolated static let defaultFitExtent: Float = 0.22

    nonisolated static let frenchAngelfish = FieldGuideMarineLifeHeroSceneConfiguration(
        modelResourceName: "FrenchAngelfish",
        fitExtent: defaultFitExtent,
        modelForwardOffset: -0.08,
        modelVerticalOffset: -0.09,
        initialYawRadians: -.pi / 5,
        autoRotateSpeedRadiansPerSecond: 0.225,
        autoSpinPauseAfterDragSeconds: 15,
        allowsDragRotation: true,
        showsGlow: true
    )
}

/// Maps catalog species size → RealityKit **`fitExtent`** with a non-linear curve.
///
/// Mid-band lengths (**0.5–6 ft**) get the most visual size difference; tiny (under **0.5 ft**)
/// and huge (over **6 ft**) species compress toward the ends of the fit range.
enum FieldGuideMarineLifeHeroFitExtentPresentation: Sendable {
    /// Small-band ceiling / large-band floor in feet (user-facing size bands).
    nonisolated static let smallBandCeilingFeet: Double = 0.5
    nonisolated static let largeBandFloorFeet: Double = 6.0
    /// Diminishing-returns length above **6 ft** (same units as the band floor).
    nonisolated static let largeBandAsymptoteFeet: Double = 8.0
    /// Same scale as dive display conversion (**m → ft**).
    nonisolated static let feetPerMeter: Double = 3.280839895013123

    /// Scene units — longest model axis after load.
    nonisolated static let minFitExtent: Float = 0.145
    nonisolated static let maxFitExtent: Float = 0.285
    /// Normalized weight **0…1** at the mid-band edges (steep slope between these).
    /// Small-band ceiling stays low so per-foot change is largest through **0.5–6 ft**.
    nonisolated static let weightAtSmallBandCeiling: Double = 0.05
    nonisolated static let weightAtLargeBandFloor: Double = 0.82

    /// Average of min/max when both exist; otherwise the non-zero side; **0** if unknown.
    nonisolated static func representativeSizeMeters(
        minSizeMeters: Double,
        maxSizeMeters: Double
    ) -> Double {
        let minSize = minSizeMeters > 0 ? minSizeMeters : 0
        let maxSize = maxSizeMeters > 0 ? maxSizeMeters : 0
        if minSize > 0, maxSize > 0 {
            return (minSize + maxSize) / 2
        }
        if maxSize > 0 { return maxSize }
        if minSize > 0 { return minSize }
        return 0
    }

    nonisolated static func sizeFeet(fromMeters meters: Double) -> Double {
        meters * feetPerMeter
    }

    /// **0…1** size weight — shallow below **0.5 ft**, steep through **6 ft**, asymptotic after.
    nonisolated static func sizeWeight(feet: Double) -> Double {
        let clampedFeet = Swift.max(feet, 0)
        if clampedFeet <= smallBandCeilingFeet {
            let u = smallBandCeilingFeet > 0 ? clampedFeet / smallBandCeilingFeet : 0
            return weightAtSmallBandCeiling * u
        }
        if clampedFeet <= largeBandFloorFeet {
            let span = largeBandFloorFeet - smallBandCeilingFeet
            let u = span > 0 ? (clampedFeet - smallBandCeilingFeet) / span : 1
            return weightAtSmallBandCeiling
                + (weightAtLargeBandFloor - weightAtSmallBandCeiling) * u
        }
        let remaining = 1 - weightAtLargeBandFloor
        let asymptote = Swift.max(largeBandAsymptoteFeet, 0.001)
        let u = 1 - exp(-(clampedFeet - largeBandFloorFeet) / asymptote)
        return weightAtLargeBandFloor + remaining * u
    }

    nonisolated static func fitExtent(forSizeMeters meters: Double) -> Float {
        guard meters > 0 else {
            return FieldGuideMarineLifeHeroSceneConfiguration.defaultFitExtent
        }
        let weight = sizeWeight(feet: sizeFeet(fromMeters: meters))
        let span = maxFitExtent - minFitExtent
        return minFitExtent + span * Float(weight)
    }

    nonisolated static func fitExtent(
        minSizeMeters: Double,
        maxSizeMeters: Double
    ) -> Float {
        fitExtent(
            forSizeMeters: representativeSizeMeters(
                minSizeMeters: minSizeMeters,
                maxSizeMeters: maxSizeMeters
            )
        )
    }
}

/// Soft light-blue glow disc parameters under Field Guide **3D** heroes (RealityKit).
enum FieldGuideMarineLifeHeroGlowPresentation: Sendable {
    struct Layer: Equatable, Sendable {
        /// Multiplier of the base glow radius.
        let radiusScale: Float
        /// Relative brightness for additive accent tint (**0…1**).
        let intensity: Float
    }

    /// Brand accent (light-mode ocean blue) used for the glow tint.
    nonisolated static let accentRed: Float = 0.00
    nonisolated static let accentGreen: Float = 0.48
    nonisolated static let accentBlue: Float = 0.72

    /// Glow radius relative to the fitted longest model axis.
    nonisolated static let radiusRelativeToFitExtent: Float = 0.72
    /// Thin cylinder height so the disc reads as a flat ground plate.
    nonisolated static let discHeight: Float = 0.0018
    /// Gap below the fitted model’s lowest point so the plate sits under the mesh
    /// but still above the blue-sheet seam in the hero band.
    nonisolated static let verticalClearance: Float = 0.36

    /// Peak horizontal scale oscillation for the breathing disc (**±** this amount).
    nonisolated static let pulseAmplitude: Float = 0.10
    /// Radians/sec for the disc breathe cycle (~2.4 → ~0.4 Hz).
    nonisolated static let pulseAngularSpeed: Float = 2.4
    /// Soft vertical bob amplitude (meters) synchronized with the pulse.
    nonisolated static let pulseVerticalAmplitude: Float = 0.0018
    nonisolated static let pulseVerticalAngularSpeed: Float = 1.85

    /// Soft sparkle emitters rising from the plate (world **+Y**, hemispheric spray).
    nonisolated static let particleBirthRate: Float = 28
    nonisolated static let particleSize: Float = 0.007
    /// Longer life so sparkles travel farther before fading out.
    nonisolated static let particleLifeSpan: TimeInterval = 3.4
    nonisolated static let particleSpeed: Float = 0.078
    nonisolated static let particleSpeedVariation: Float = 0.032
    /// Hemispheric cone around world **+Y** (**π/2** ≈ all outward directions above the plate).
    nonisolated static let particleSpreadingAngle: Float = .pi / 2
    /// Emitter footprint relative to the glow base radius (wider birth ring).
    nonisolated static let particleEmitterRadiusScale: Float = 1.15
    /// Thin plate volume so births stay under the model, not inside it.
    nonisolated static let particleEmitterHeight: Float = 0.006
    nonisolated static let particleEmissionDirection: SIMD3<Float> = [0, 1, 0]

    nonisolated static let layers: [Layer] = [
        Layer(radiusScale: 1.00, intensity: 0.55),
        Layer(radiusScale: 1.40, intensity: 0.28),
        Layer(radiusScale: 1.85, intensity: 0.12),
    ]

    nonisolated static func baseRadius(fitExtent: Float) -> Float {
        Swift.max(fitExtent * radiusRelativeToFitExtent, 0.04)
    }

    /// World **Y** for the glow plate — well **below** the fitted model’s lowest point.
    nonisolated static func discY(
        modelPositionY: Float,
        modelExtentY: Float,
        modelScale: Float
    ) -> Float {
        modelPositionY - (modelExtentY * modelScale * 0.5) - verticalClearance
    }

    /// Horizontal center under the model’s yaw spin axis (**model anchor origin**).
    nonisolated static func discPositionUnderSpinAxis(glowY: Float) -> SIMD3<Float> {
        [0, glowY, 0]
    }

    nonisolated static func tintRGB(intensity: Float) -> (red: Float, green: Float, blue: Float) {
        let clamped = Swift.min(Swift.max(intensity, 0), 1)
        return (
            accentRed * clamped,
            accentGreen * clamped,
            accentBlue * clamped
        )
    }

    /// Horizontal breathe scale for glow discs (**1 ± amplitude**).
    nonisolated static func pulseScale(elapsed: TimeInterval) -> Float {
        1 + pulseAmplitude * sin(Float(elapsed) * pulseAngularSpeed)
    }

    nonisolated static func pulseVerticalOffset(elapsed: TimeInterval) -> Float {
        pulseVerticalAmplitude * sin(Float(elapsed) * pulseVerticalAngularSpeed)
    }

    nonisolated static func particleEmitterShapeSize(baseRadius: Float) -> SIMD3<Float> {
        let radius = baseRadius * particleEmitterRadiusScale
        return [radius, particleEmitterHeight, radius]
    }
}

/// Slow vertical float for Field Guide **3D** species models (applied with yaw spin).
enum FieldGuideMarineLifeHeroModelMotionPresentation: Sendable {
    /// Rise/fall amplitude in scene units (~**3×** the initial subtle float).
    nonisolated static let bobAmplitude: Float = 0.042
    /// Radians/sec — slow float (~**0.18 Hz**), independent of spin rate.
    nonisolated static let bobAngularSpeed: Float = 1.15

    nonisolated static func bobOffset(elapsed: TimeInterval) -> Float {
        bobAmplitude * sin(Float(elapsed) * bobAngularSpeed)
    }
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
        featureImageURL: String,
        minSizeMeters: Double = 0,
        maxSizeMeters: Double = 0
    ) -> HeroKind {
        let modelName = featureModelResourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !modelName.isEmpty {
            return .model3D(
                sceneConfiguration(
                    forModelResourceName: modelName,
                    minSizeMeters: minSizeMeters,
                    maxSizeMeters: maxSizeMeters
                )
            )
        }

        return catalogImageKind(
            featureImageResourceName: featureImageResourceName,
            featureImageURL: featureImageURL
        ) ?? .placeholder
    }

    /// Dive **Media** sheet / tagged-species overlays — catalog photo first; 3D only when no image.
    nonisolated static func mediaOverlayHeroKind(
        featureModelResourceName: String,
        featureImageResourceName: String,
        featureImageURL: String,
        minSizeMeters: Double = 0,
        maxSizeMeters: Double = 0
    ) -> HeroKind {
        if let imageKind = catalogImageKind(
            featureImageResourceName: featureImageResourceName,
            featureImageURL: featureImageURL
        ) {
            return imageKind
        }
        return heroKind(
            featureModelResourceName: featureModelResourceName,
            featureImageResourceName: featureImageResourceName,
            featureImageURL: featureImageURL,
            minSizeMeters: minSizeMeters,
            maxSizeMeters: maxSizeMeters
        )
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
        forModelResourceName resourceName: String,
        minSizeMeters: Double = 0,
        maxSizeMeters: Double = 0
    ) -> FieldGuideMarineLifeHeroSceneConfiguration {
        let fitExtent = FieldGuideMarineLifeHeroFitExtentPresentation.fitExtent(
            minSizeMeters: minSizeMeters,
            maxSizeMeters: maxSizeMeters
        )
        switch resourceName {
        case FieldGuideMarineLifeHeroSceneConfiguration.frenchAngelfish.modelResourceName:
            let base = FieldGuideMarineLifeHeroSceneConfiguration.frenchAngelfish
            return FieldGuideMarineLifeHeroSceneConfiguration(
                modelResourceName: base.modelResourceName,
                fitExtent: fitExtent,
                modelForwardOffset: base.modelForwardOffset,
                modelVerticalOffset: base.modelVerticalOffset,
                initialYawRadians: base.initialYawRadians,
                autoRotateSpeedRadiansPerSecond: base.autoRotateSpeedRadiansPerSecond,
                autoSpinPauseAfterDragSeconds: base.autoSpinPauseAfterDragSeconds,
                allowsDragRotation: base.allowsDragRotation,
                showsGlow: base.showsGlow
            )
        default:
            return FieldGuideMarineLifeHeroSceneConfiguration(
                modelResourceName: resourceName,
                fitExtent: fitExtent,
                modelForwardOffset: -0.08,
                modelVerticalOffset: -0.09,
                initialYawRadians: 0,
                autoRotateSpeedRadiansPerSecond: 0.225,
                autoSpinPauseAfterDragSeconds: 15,
                allowsDragRotation: true,
                showsGlow: true
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
