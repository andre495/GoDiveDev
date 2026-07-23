import Foundation

/// Frosted translucent overlay on dive **Media** and media-grid playback (tag overview).
/// Always uses the dark-mode material/text palette so light mode matches the same gray frost.
enum DiveActivityMediaFrostedOverlayPresentation: Sendable {
    /// Whether translucent Media chrome forces **dark** appearance (material + content tokens).
    nonisolated static let forcesDarkAppearance = true

    /// Black scrim over **`.thinMaterial`** — same stack as Home header fish overlay (**`HomeMediaCarouselMarineLifeOverlay`**).
    nonisolated static let mediaScrimOpacity: Double =
        HomeMediaCarouselPresentation.marineLifeCarouselOverlayMediaScrimOpacity
}
