import SwiftData
import SwiftUI

/// Category-aware minimalist search hit row for global search results.
struct GlobalSearchScopedResultLabel: View {
    let hit: GlobalSearchPresentation.Hit
    let ownerProfileID: UUID?
    let ownerDives: [DiveActivity]
    let diveSites: [DiveSite]
    let speciesCatalog: [MarineLife]
    let ownerDiveBuddies: [DiveBuddy]
    let ownerTrips: [DiveTrip]
    let ownerEquipment: [EquipmentItem]
    let ownerCertifications: [Certification]
    let unitSystem: DiveDisplayUnitSystem
    let useChronologicalNumbers: Bool

    var body: some View {
        Group {
            switch hit.destination {
            case .dive(let id):
                if let rowData = diveRowData(for: id) {
                    GlobalSearchDiveResultListRow(data: rowData)
                } else {
                    fallbackRow
                }
            case .diveSite(let id):
                if let rowData = siteRowData(for: id) {
                    GlobalSearchResultListRow(
                        title: rowData.displayName,
                        subtitle: siteSubtitle(for: rowData)
                    ) {
                        GlobalSearchResultSymbolArtwork(systemName: "mappin.and.ellipse")
                    }
                } else {
                    fallbackRow
                }
            case .referenceSite(let referenceID):
                if let rowData = referenceSiteRowData(for: referenceID) {
                    GlobalSearchResultListRow(
                        title: rowData.displayName,
                        subtitle: siteSubtitle(for: rowData)
                    ) {
                        GlobalSearchResultSymbolArtwork(systemName: "mappin.and.ellipse")
                    }
                } else {
                    fallbackRow
                }
            case .species(let uuid):
                if let rowData = speciesRowData(for: uuid),
                   let snapshot = speciesSnapshot(for: uuid) {
                    GlobalSearchResultListRow(
                        title: rowData.displayName,
                        subtitle: rowData.detailLine
                    ) {
                        GlobalSearchResultSpeciesArtwork(snapshot: snapshot)
                    }
                } else {
                    fallbackRow
                }
            case .buddy(let id):
                if let buddy = ownerDiveBuddies.first(where: { $0.id == id }) {
                    GlobalSearchResultListRow(
                        title: buddy.displayName,
                        subtitle: DiveBuddyRosterPresentation.listSubtitle(
                            sharedDiveCount: sharedDiveCount(for: buddy)
                        )
                    ) {
                        GlobalSearchResultAvatarArtwork(
                            profilePhoto: buddy.profilePhoto,
                            initials: DiveBuddyPresentation.initials(from: buddy.displayName)
                        )
                    }
                } else {
                    fallbackRow
                }
            case .tag:
                GlobalSearchResultListRow(
                    title: hit.title,
                    subtitle: hit.subtitle
                ) {
                    GlobalSearchResultSymbolArtwork(systemName: "tag.fill")
                }
            case .trip(let id):
                if let rowData = tripRowData(for: id) {
                    GlobalSearchResultListRow(
                        title: rowData.title,
                        subtitle: tripSubtitle(for: rowData)
                    ) {
                        if let previewMediaPhotoID = rowData.previewMediaPhotoID {
                            GlobalSearchResultMediaArtwork(photoID: previewMediaPhotoID)
                        } else {
                            GlobalSearchResultSymbolArtwork(systemName: "airplane")
                        }
                    }
                } else {
                    fallbackRow
                }
            case .equipment(let id):
                if let item = ownerEquipment.first(where: { $0.id == id }) {
                    equipmentRow(for: item)
                } else {
                    fallbackRow
                }
            case .certification(let id):
                if let certification = ownerCertifications.first(where: { $0.id == id }) {
                    certificationRow(for: certification)
                } else {
                    fallbackRow
                }
            }
        }
    }

    @ViewBuilder
    private var fallbackRow: some View {
        GlobalSearchResultListRow(
            title: hit.title,
            subtitle: hit.subtitle
        ) {
            GlobalSearchResultSymbolArtwork(systemName: hit.systemImage)
        }
    }

    #if canImport(UIKit)
    @ViewBuilder
    private func equipmentRow(for item: EquipmentItem) -> some View {
        GlobalSearchResultListRow(
            title: EquipmentItemPresentation.title(for: item),
            subtitle: equipmentSubtitle(for: item)
        ) {
            GlobalSearchResultPhotoArtwork(
                photoData: item.equipmentPhoto,
                placeholderSystemName: "archivebox.fill"
            )
        }
    }

    @ViewBuilder
    private func certificationRow(for certification: Certification) -> some View {
        GlobalSearchResultListRow(
            title: CertificationPresentation.title(for: certification),
            subtitle: CertificationPresentation.subtitle(for: certification)
        ) {
            GlobalSearchResultPhotoArtwork(
                photoData: certification.certFrontPicture,
                placeholderSystemName: "checkmark.seal.fill"
            )
        }
    }
    #else
    @ViewBuilder
    private func equipmentRow(for item: EquipmentItem) -> some View {
        GlobalSearchResultListRow(
            title: EquipmentItemPresentation.title(for: item),
            subtitle: equipmentSubtitle(for: item)
        ) {
            GlobalSearchResultSymbolArtwork(systemName: "archivebox.fill")
        }
    }

    @ViewBuilder
    private func certificationRow(for certification: Certification) -> some View {
        GlobalSearchResultListRow(
            title: CertificationPresentation.title(for: certification),
            subtitle: CertificationPresentation.subtitle(for: certification)
        ) {
            GlobalSearchResultSymbolArtwork(systemName: "checkmark.seal.fill")
        }
    }
    #endif

    private func siteSubtitle(for rowData: ExploreDiveSiteRowDisplayData) -> String {
        if rowData.placeLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return rowData.coordinateLine
        }
        return rowData.placeLine
    }

    private func tripSubtitle(for rowData: TripPlannerListRowDisplayData) -> String {
        var parts = [rowData.secondaryDetailLine]
        if let linkedDiveCountLabel = rowData.linkedDiveCountLabel {
            parts.append(linkedDiveCountLabel)
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func equipmentSubtitle(for item: EquipmentItem) -> String {
        var parts = [EquipmentItemPresentation.gearTypeLabel(for: item)]
        if item.isRetired {
            parts.append("Retired")
        }
        return parts.joined(separator: " · ")
    }

    private func diveRowData(for id: UUID) -> DiveLogbookRowDisplayData? {
        guard let activity = ownerDives.first(where: { $0.id == id }) else { return nil }
        return DiveLogbookDisplay.rowData(
            activities: [activity],
            unitSystem: unitSystem,
            duplicateIds: [],
            useChronologicalNumbers: useChronologicalNumbers,
            numberingActivities: ownerDives
        ).first
    }

    private func siteRowData(for id: UUID) -> ExploreDiveSiteRowDisplayData? {
        guard let site = diveSites.first(where: { $0.id == id }) else { return nil }
        return ExploreDiveSiteListDisplay.rowData(for: [site]).first
    }

    private func referenceSiteRowData(for referenceID: String) -> ExploreDiveSiteRowDisplayData? {
        guard let snapshot = DiveSiteReferenceCatalog.bundledReference().first(where: { $0.id == referenceID })
        else { return nil }
        return ExploreReferenceSiteListDisplay.rowData(for: [snapshot]).first
    }

    private func speciesRowData(for uuid: String) -> FieldGuidePresentation.MarineLifeRowDisplayData? {
        guard let species = speciesCatalog.first(where: { $0.uuid == uuid }) else { return nil }
        return FieldGuidePresentation.marineLifeRowDisplayData(
            for: species.fieldGuideCatalogSnapshot,
            unitSystem: unitSystem,
            isSighted: false
        )
    }

    private func speciesSnapshot(for uuid: String) -> MarineLifeCatalogSnapshot? {
        speciesCatalog.first(where: { $0.uuid == uuid })?.fieldGuideCatalogSnapshot
    }

    private func tripRowData(for id: UUID) -> TripPlannerListRowDisplayData? {
        guard let trip = ownerTrips.first(where: { $0.id == id }) else { return nil }
        let phase = TripPlannerPresentation.lifecyclePhase(for: trip)
        return TripPlannerPresentation.listRowDisplayData(for: trip, phase: phase)
    }

    private func sharedDiveCount(for buddy: DiveBuddy) -> Int {
        guard let ownerProfileID else { return 0 }
        return DiveBuddyRosterPresentation.sharedDiveCount(for: buddy, ownerProfileID: ownerProfileID)
    }
}
