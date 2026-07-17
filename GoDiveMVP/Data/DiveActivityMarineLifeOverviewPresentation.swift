import CoreGraphics
import Foundation

/// Unique species on a dive for the map-tab **Marine Life** overview (media tags + dive-level tags).
enum DiveActivityMarineLifeOverviewPresentation: Sendable {

    nonisolated static let sectionTitle = "Marine Life"
    nonisolated static let emptyValue = "—"
    nonisolated static let avatarDiameter: CGFloat = 56

    /// Fixed RealityKit fit for the circular avatar — every species renders at the same
    /// maximum size that still clears the circle edge (not the species-size-based hero fit).
    nonisolated static let avatarModelFitExtent: Float = 0.42

    enum AvatarKind: Equatable, Sendable {
        case model3D(resourceName: String)
        case photo(resourceName: String, imageURL: String)
        case fishIcon

        /// Explicit **nonisolated** equality for Swift Testing **`#expect`** (Swift 6).
        nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.fishIcon, .fishIcon):
                return true
            case (.model3D(let left), .model3D(let right)):
                return left == right
            case (.photo(let leftResource, let leftURL), .photo(let rightResource, let rightURL)):
                return leftResource == rightResource && leftURL == rightURL
            default:
                return false
            }
        }
    }

    struct SpeciesChip: Identifiable, Equatable, Sendable {
        var id: String { marineLifeUUID }
        let marineLifeUUID: String
        let commonName: String
        let featureModelResourceName: String
        let featureImageResourceName: String
        let featureImageURL: String
        let minSizeMeters: Double
        let maxSizeMeters: Double

        var avatarKind: AvatarKind {
            resolvedAvatarKind(
                featureModelResourceName: featureModelResourceName,
                featureImageResourceName: featureImageResourceName,
                featureImageURL: featureImageURL
            )
        }
    }

    /// Dedupes by **`marineLifeUUID`** so media + dive-level tags of the same species appear once.
    nonisolated static func uniqueSpeciesChips(
        sightings: [SightingInstance],
        catalog: [MarineLife] = []
    ) -> [SpeciesChip] {
        let catalogByUUID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.uuid, $0) })
        var seen = Set<String>()
        var chips: [SpeciesChip] = []

        for sighting in sightings {
            let uuid = sighting.marineLifeUUID
            guard seen.insert(uuid).inserted else { continue }
            let species = sighting.marineLife ?? catalogByUUID[uuid]
            guard let species else { continue }
            chips.append(
                SpeciesChip(
                    marineLifeUUID: species.uuid,
                    commonName: species.commonName,
                    featureModelResourceName: species.featureModelResourceName,
                    featureImageResourceName: species.featureImageResourceName,
                    featureImageURL: species.featureImageURL,
                    minSizeMeters: species.minSizeMeters,
                    maxSizeMeters: species.maxSizeMeters
                )
            )
        }

        return chips.sorted {
            $0.commonName.localizedCaseInsensitiveCompare($1.commonName) == .orderedAscending
        }
    }

    nonisolated static func uniqueMarineLifeUUIDs(from sightings: [SightingInstance]) -> Set<String> {
        Set(sightings.map(\.marineLifeUUID))
    }

    nonisolated static func resolvedAvatarKind(
        featureModelResourceName: String,
        featureImageResourceName: String,
        featureImageURL: String
    ) -> AvatarKind {
        let model = featureModelResourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !model.isEmpty {
            return .model3D(resourceName: model)
        }
        let resource = featureImageResourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = featureImageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !resource.isEmpty || !url.isEmpty {
            return .photo(resourceName: resource, imageURL: url)
        }
        return .fishIcon
    }

    /// Compact RealityKit config for buddy-sized avatar chips (no drag, no glow).
    ///
    /// Uses a fixed **`avatarModelFitExtent`** so the model fills the circle at its maximum
    /// size regardless of species size, centered vertically (no hero downshift), and drops
    /// the accent glow plate — the glow only belongs on the species detail hero.
    nonisolated static func compactModelSceneConfiguration(
        resourceName: String,
        minSizeMeters: Double = 0,
        maxSizeMeters: Double = 0
    ) -> FieldGuideMarineLifeHeroSceneConfiguration {
        let base = FieldGuideMarineLifeHeroPresentation.sceneConfiguration(
            forModelResourceName: resourceName,
            minSizeMeters: minSizeMeters,
            maxSizeMeters: maxSizeMeters
        )
        return FieldGuideMarineLifeHeroSceneConfiguration(
            modelResourceName: base.modelResourceName,
            fitExtent: avatarModelFitExtent,
            modelForwardOffset: base.modelForwardOffset,
            modelVerticalOffset: 0,
            initialYawRadians: base.initialYawRadians,
            autoRotateSpeedRadiansPerSecond: base.autoRotateSpeedRadiansPerSecond,
            autoSpinPauseAfterDragSeconds: base.autoSpinPauseAfterDragSeconds,
            allowsDragRotation: false,
            showsGlow: false
        )
    }
}
