import Foundation

/// Hero media source on **`FieldGuideMarineLifeDetailView`** when the owner has tagged media.
enum FieldGuideSpeciesHeroMediaSource: String, Equatable, Sendable {
    case taggedUserMedia
    case catalogReference
}

/// Catalog hero presentation — dataset image vs bundled 3D model.
enum FieldGuideSpeciesCatalogHeroDisplay: String, Equatable, Sendable {
    case image
    case model3D
}

struct FieldGuideSpeciesCatalogHeroAvailability: Equatable, Sendable {
    let hasModel3D: Bool
    let hasImage: Bool

    nonisolated var supportsHeaderToggle: Bool {
        hasModel3D && hasImage
    }
}

/// Tagged vs catalog hero selection for Field Guide species detail.
enum FieldGuideSpeciesHeroPresentation: Sendable {
    /// Half the buddy profile avatar diameter — compact hero source preview circle.
    nonisolated static let sourceToggleDiameter: CGFloat =
        DiveBuddyDetailPresentation.profileAvatarDiameter / 2

    nonisolated static func showsSourceToggle(hasTaggedMedia: Bool) -> Bool {
        hasTaggedMedia
    }

    nonisolated static func toggledSource(_ current: FieldGuideSpeciesHeroMediaSource) -> FieldGuideSpeciesHeroMediaSource {
        switch current {
        case .taggedUserMedia:
            return .catalogReference
        case .catalogReference:
            return .taggedUserMedia
        }
    }

    /// Default hero source when the page opens — owner tagged media when available.
    nonisolated static func defaultMediaSource(hasTaggedMedia: Bool) -> FieldGuideSpeciesHeroMediaSource {
        hasTaggedMedia ? .taggedUserMedia : .catalogReference
    }

    /// Prefer the first tagged video; otherwise the first gallery item.
    nonisolated static func initialTaggedMediaPhotoID(from photos: [DiveMediaPhoto]) -> UUID? {
        guard !photos.isEmpty else { return nil }
        if let videoID = photos.first(where: { $0.resolvedMediaKind == .video })?.id {
            return videoID
        }
        return photos.first?.id
    }

    nonisolated static func resolvedTaggedMedia(
        selectedID: UUID?,
        in photos: [DiveMediaPhoto]
    ) -> DiveMediaPhoto? {
        guard !photos.isEmpty else { return nil }
        if let selectedID,
           let selected = photos.first(where: { $0.id == selectedID }) {
            return selected
        }
        return photos.first(where: { $0.resolvedMediaKind == .video }) ?? photos.first
    }

    nonisolated static func sourceToggleAccessibilityLabel(
        currentSource: FieldGuideSpeciesHeroMediaSource,
        commonName: String
    ) -> String {
        let name = commonName.trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = name.isEmpty ? "this species" : name
        switch currentSource {
        case .taggedUserMedia:
            return "Show catalog reference for \(subject)"
        case .catalogReference:
            return "Show your tagged media for \(subject)"
        }
    }

    nonisolated static func catalogHeroAvailability(
        featureModelResourceName: String,
        featureImageResourceName: String,
        featureImageURL: String
    ) -> FieldGuideSpeciesCatalogHeroAvailability {
        FieldGuideSpeciesCatalogHeroAvailability(
            hasModel3D: FieldGuideMarineLifeHeroPresentation.hasCatalogModel(
                featureModelResourceName: featureModelResourceName
            ),
            hasImage: FieldGuideMarineLifeHeroPresentation.catalogImageKind(
                featureImageResourceName: featureImageResourceName,
                featureImageURL: featureImageURL
            ) != nil
        )
    }

    /// Catalog hero opens on the dataset image when both image and 3D exist.
    nonisolated static func defaultCatalogHeroDisplay(
        availability: FieldGuideSpeciesCatalogHeroAvailability
    ) -> FieldGuideSpeciesCatalogHeroDisplay {
        if availability.hasImage {
            return .image
        }
        if availability.hasModel3D {
            return .model3D
        }
        return .image
    }

    nonisolated static func resolvedCatalogHeroDisplay(
        selection: FieldGuideSpeciesCatalogHeroDisplay,
        availability: FieldGuideSpeciesCatalogHeroAvailability
    ) -> FieldGuideSpeciesCatalogHeroDisplay {
        if availability.supportsHeaderToggle {
            return selection
        }
        if availability.hasModel3D, !availability.hasImage {
            return .model3D
        }
        return .image
    }

    nonisolated static func toggledCatalogHeroDisplay(
        _ current: FieldGuideSpeciesCatalogHeroDisplay
    ) -> FieldGuideSpeciesCatalogHeroDisplay {
        switch current {
        case .image:
            return .model3D
        case .model3D:
            return .image
        }
    }

    nonisolated static func catalogHeroHeaderAccessibilityLabel(
        display: FieldGuideSpeciesCatalogHeroDisplay,
        supportsToggle: Bool
    ) -> String {
        guard supportsToggle else {
            switch display {
            case .image:
                return "Catalog reference image"
            case .model3D:
                return "Catalog 3D model"
            }
        }
        switch display {
        case .image:
            return "Catalog reference image. Tap to show 3D model."
        case .model3D:
            return "Catalog 3D model. Tap to show reference image."
        }
    }

    nonisolated static func compactSceneConfiguration(
        for configuration: FieldGuideMarineLifeHeroSceneConfiguration
    ) -> FieldGuideMarineLifeHeroSceneConfiguration {
        FieldGuideMarineLifeHeroSceneConfiguration(
            modelResourceName: configuration.modelResourceName,
            fitExtent: configuration.fitExtent,
            modelForwardOffset: configuration.modelForwardOffset,
            modelVerticalOffset: configuration.modelVerticalOffset,
            initialYawRadians: configuration.initialYawRadians,
            autoRotateSpeedRadiansPerSecond: configuration.autoRotateSpeedRadiansPerSecond,
            autoSpinPauseAfterDragSeconds: configuration.autoSpinPauseAfterDragSeconds,
            allowsDragRotation: false,
            showsGlow: configuration.showsGlow
        )
    }

    /// How far the catalog still extends below the hero band into the blue-sheet overlap.
    nonisolated static let catalogPhotoSeamUnderlap: CGFloat = 36

    /// Tuned on device — vertical nudge for the catalog JPEG hero (negative moves up).
    nonisolated static let catalogPhotoVerticalOffset: CGFloat = -206

    /// True when the hero is showing owner tagged photo/video (not catalog reference).
    nonisolated static func isShowingTaggedMediaHero(
        mediaSource: FieldGuideSpeciesHeroMediaSource,
        heroTaggedMedia: DiveMediaPhoto?,
        taggedMediaItemsEmpty: Bool
    ) -> Bool {
        guard mediaSource == .taggedUserMedia else { return false }
        if heroTaggedMedia != nil { return true }
        return !taggedMediaItemsEmpty
    }

    /// Catalog JPEG heroes bottom-align and underlap the sheet seam; 3D / video / map unchanged.
    nonisolated static func usesCatalogPhotoSeamUnderlapLayout(
        heroMode: PushedDetailHeroHeaderView.Mode,
        mediaSource: FieldGuideSpeciesHeroMediaSource,
        catalogHeroDisplay: FieldGuideSpeciesCatalogHeroDisplay,
        isShowingTaggedMedia: Bool
    ) -> Bool {
        guard heroMode == .media, !isShowingTaggedMedia else { return false }
        return catalogHeroDisplay == .image
    }
}
