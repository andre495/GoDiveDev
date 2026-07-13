import Foundation
import SwiftData

/// Precomputed, value-type (**`Equatable`**) content for one global-search result row.
///
/// Search rows used to resolve their display data inside SwiftUI `body` (linear scans over all
/// dives/sites/species/buddies plus a `first(where:)` over the thousands-row OpenDiveMap reference
/// catalog, and a full `DiveLogbookDisplay.rowData` numbering pass per dive). Because the row views
/// were handed large, non-`Equatable` model arrays, SwiftUI re-ran that work for every visible row on
/// every scroll frame — the cause of the search-results frame drops. This model is built **once** per
/// results change so scrolling only diffs cheap value types.
struct GlobalSearchResultRowContent: Identifiable, Equatable {
    let id: String
    let destination: GlobalSearchPresentation.Destination
    let accessibilityIdentifier: String
    let matchReasons: [GlobalSearchPresentation.MatchReason]
    let kind: Kind

    enum Kind: Equatable {
        case dive(DiveLogbookRowDisplayData)
        case standard(title: String, subtitle: String?, artwork: Artwork)
    }

    enum Artwork: Equatable {
        case symbol(String)
        case media(UUID)
        case species(MarineLifeCatalogSnapshot)
        case avatar(profilePhoto: Data?, initials: String)
        case photo(data: Data?, placeholder: String)
    }
}

/// Builds **`GlobalSearchResultRowContent`** for a set of hits in a single pass. Runs on the main actor
/// (reads SwiftData models) but only when results change — not per scroll frame. All per-hit lookups
/// are O(1) via dictionaries, and dive numbering is computed once over the owner's dives.
@MainActor
enum GlobalSearchResultRowContentBuilder {
    static func rowContents(
        hits: [GlobalSearchPresentation.Hit],
        ownerProfileID: UUID?,
        ownerDives: [DiveActivity],
        diveSites: [DiveSite],
        speciesCatalog: [MarineLife],
        ownerDiveBuddies: [DiveBuddy],
        ownerTrips: [DiveTrip],
        ownerEquipment: [EquipmentItem],
        ownerCertifications: [Certification],
        unitSystem: DiveDisplayUnitSystem,
        useChronologicalNumbers: Bool
    ) -> [GlobalSearchResultRowContent] {
        let divesByID = Dictionary(ownerDives.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let sitesByID = Dictionary(diveSites.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let speciesByUUID = Dictionary(speciesCatalog.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        let buddiesByID = Dictionary(ownerDiveBuddies.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let tripsByID = Dictionary(ownerTrips.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let equipmentByID = Dictionary(ownerEquipment.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let certsByID = Dictionary(ownerCertifications.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let referenceByID = DiveSiteReferenceCatalog.bundledReferenceByID()

        // Batch dive rows: compute numbering once across all owner dives instead of per dive hit.
        let diveActivities: [DiveActivity] = hits.compactMap { hit in
            guard case .dive(let id) = hit.destination else { return nil }
            return divesByID[id]
        }
        let diveRowDataByID = Dictionary(
            DiveLogbookDisplay.rowData(
                activities: diveActivities,
                unitSystem: unitSystem,
                duplicateIds: [],
                useChronologicalNumbers: useChronologicalNumbers,
                numberingActivities: ownerDives
            ).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return hits.map { hit in
            let kind = kind(
                for: hit,
                diveRowDataByID: diveRowDataByID,
                sitesByID: sitesByID,
                referenceByID: referenceByID,
                speciesByUUID: speciesByUUID,
                buddiesByID: buddiesByID,
                tripsByID: tripsByID,
                equipmentByID: equipmentByID,
                certsByID: certsByID,
                ownerProfileID: ownerProfileID,
                unitSystem: unitSystem
            )
            return GlobalSearchResultRowContent(
                id: hit.id,
                destination: hit.destination,
                accessibilityIdentifier: hit.accessibilityIdentifier,
                matchReasons: hit.matchReasons,
                kind: kind
            )
        }
    }

    private static func kind(
        for hit: GlobalSearchPresentation.Hit,
        diveRowDataByID: [UUID: DiveLogbookRowDisplayData],
        sitesByID: [UUID: DiveSite],
        referenceByID: [String: DiveSiteReferenceSnapshot],
        speciesByUUID: [String: MarineLife],
        buddiesByID: [UUID: DiveBuddy],
        tripsByID: [UUID: DiveTrip],
        equipmentByID: [UUID: EquipmentItem],
        certsByID: [UUID: Certification],
        ownerProfileID: UUID?,
        unitSystem: DiveDisplayUnitSystem
    ) -> GlobalSearchResultRowContent.Kind {
        switch hit.destination {
        case .dive(let id):
            if let data = diveRowDataByID[id] {
                return .dive(data)
            }
        case .diveSite(let id):
            if let site = sitesByID[id],
               let rowData = ExploreDiveSiteListDisplay.rowData(for: [site]).first {
                return .standard(
                    title: rowData.displayName,
                    subtitle: siteSubtitle(for: rowData),
                    artwork: .symbol("mappin.and.ellipse")
                )
            }
        case .referenceSite(let referenceID):
            if let snapshot = referenceByID[referenceID],
               let rowData = ExploreReferenceSiteListDisplay.rowData(for: [snapshot]).first {
                return .standard(
                    title: rowData.displayName,
                    subtitle: siteSubtitle(for: rowData),
                    artwork: .symbol("mappin.and.ellipse")
                )
            }
        case .species(let uuid):
            if let species = speciesByUUID[uuid] {
                let snapshot = species.fieldGuideCatalogSnapshot
                let rowData = FieldGuidePresentation.marineLifeRowDisplayData(
                    for: snapshot,
                    unitSystem: unitSystem,
                    isSighted: false
                )
                return .standard(
                    title: rowData.displayName,
                    subtitle: rowData.detailLine,
                    artwork: .species(snapshot)
                )
            }
        case .buddy(let id):
            if let buddy = buddiesByID[id] {
                return .standard(
                    title: buddy.displayName,
                    subtitle: DiveBuddyRosterPresentation.listSubtitle(
                        sharedDiveCount: sharedDiveCount(for: buddy, ownerProfileID: ownerProfileID)
                    ),
                    artwork: .avatar(
                        profilePhoto: buddy.profilePhoto,
                        initials: DiveBuddyPresentation.initials(from: buddy.displayName)
                    )
                )
            }
        case .tag:
            return .standard(title: hit.title, subtitle: hit.subtitle, artwork: .symbol("tag.fill"))
        case .trip(let id):
            if let trip = tripsByID[id] {
                let phase = TripPlannerPresentation.lifecyclePhase(for: trip)
                let rowData = TripPlannerPresentation.listRowDisplayData(for: trip, phase: phase)
                let artwork: GlobalSearchResultRowContent.Artwork
                if let previewMediaPhotoID = rowData.previewMediaPhotoID {
                    artwork = .media(previewMediaPhotoID)
                } else {
                    artwork = .symbol("airplane")
                }
                return .standard(title: rowData.title, subtitle: tripSubtitle(for: rowData), artwork: artwork)
            }
        case .equipment(let id):
            if let item = equipmentByID[id] {
                return .standard(
                    title: EquipmentItemPresentation.title(for: item),
                    subtitle: equipmentSubtitle(for: item),
                    artwork: .photo(data: item.equipmentPhoto, placeholder: "archivebox.fill")
                )
            }
        case .certification(let id):
            if let certification = certsByID[id] {
                return .standard(
                    title: CertificationPresentation.title(for: certification),
                    subtitle: CertificationPresentation.subtitle(for: certification),
                    artwork: .photo(data: certification.certFrontPicture, placeholder: "checkmark.seal.fill")
                )
            }
        }
        return .standard(title: hit.title, subtitle: hit.subtitle, artwork: .symbol(hit.systemImage))
    }

    private static func siteSubtitle(for rowData: ExploreDiveSiteRowDisplayData) -> String {
        if rowData.placeLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return rowData.coordinateLine
        }
        return rowData.placeLine
    }

    private static func tripSubtitle(for rowData: TripPlannerListRowDisplayData) -> String {
        var parts = [rowData.secondaryDetailLine]
        if let linkedDiveCountLabel = rowData.linkedDiveCountLabel {
            parts.append(linkedDiveCountLabel)
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private static func equipmentSubtitle(for item: EquipmentItem) -> String {
        var parts = [EquipmentItemPresentation.gearTypeLabel(for: item)]
        if item.isRetired {
            parts.append("Retired")
        }
        return parts.joined(separator: " · ")
    }

    private static func sharedDiveCount(for buddy: DiveBuddy, ownerProfileID: UUID?) -> Int {
        guard let ownerProfileID else { return 0 }
        return DiveBuddyRosterPresentation.sharedDiveCount(for: buddy, ownerProfileID: ownerProfileID)
    }
}
