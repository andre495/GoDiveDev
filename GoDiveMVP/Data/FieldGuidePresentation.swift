import Foundation

/// Value snapshot of catalog species for list formatting off the **`@Model`** type (Swift 6).
struct MarineLifeCatalogSnapshot: Sendable, Equatable, Hashable {
    let uuid: String
    let commonName: String
    let scientificName: String
    let category: String
    let subcategory: String
    let familyName: String
    let featureImageURL: String
    let featureImageResourceName: String
    let featureModelResourceName: String
    let minSizeMeters: Double
    let maxSizeMeters: Double
    let minDepthMeters: Double
    let maxDepthMeters: Double
    let avgDepthMeters: Double
    let distinctiveFeatures: String
    let abundance: String
    let habitatBehavior: String
    let diverReaction: String

    nonisolated init(
        uuid: String,
        commonName: String,
        scientificName: String,
        category: String,
        subcategory: String,
        featureImageURL: String,
        featureImageResourceName: String = "",
        featureModelResourceName: String = "",
        minSizeMeters: Double,
        maxSizeMeters: Double,
        avgDepthMeters: Double,
        familyName: String = "",
        minDepthMeters: Double = 0,
        maxDepthMeters: Double = 0,
        distinctiveFeatures: String = "",
        abundance: String = "",
        habitatBehavior: String = "",
        diverReaction: String = ""
    ) {
        self.uuid = uuid
        self.commonName = commonName
        self.scientificName = scientificName
        self.category = category
        self.subcategory = subcategory
        self.familyName = familyName
        self.featureImageURL = featureImageURL
        self.featureImageResourceName = featureImageResourceName
        self.featureModelResourceName = featureModelResourceName
        self.minSizeMeters = minSizeMeters
        self.maxSizeMeters = maxSizeMeters
        self.minDepthMeters = minDepthMeters
        self.maxDepthMeters = maxDepthMeters
        self.avgDepthMeters = avgDepthMeters
        self.distinctiveFeatures = distinctiveFeatures
        self.abundance = abundance
        self.habitatBehavior = habitatBehavior
        self.diverReaction = diverReaction
    }
}

/// Dive row snapshot for Field Guide “Activities sighted on” links (Swift 6 / tests).
struct DiveActivitySightingLinkSnapshot: Sendable, Equatable {
    let id: UUID
    let diveSiteID: UUID?
    let resolvedSiteName: String?
    let startTime: Date
    let timeZoneOffsetSeconds: Int?
}

/// List / detail copy for the Field Guide marine-life catalog.
enum FieldGuidePresentation {

    struct SightedActivityLinkData: Identifiable, Equatable, Sendable {
        let id: UUID
        let title: String
        let dateText: String
    }

    struct MarineLifeRowDisplayData: Identifiable, Equatable, Sendable {
        var id: String { marineLifeUUID }
        let marineLifeUUID: String
        let displayName: String
        let trailingLabel: String
        let detailLine: String
        let isSighted: Bool
    }

    nonisolated static func rowData(
        for species: [MarineLifeCatalogSnapshot],
        sightedMarineLifeUUIDs: Set<String>,
        unitSystem: DiveDisplayUnitSystem
    ) -> [MarineLifeRowDisplayData] {
        species
            .sorted { $0.commonName.localizedCaseInsensitiveCompare($1.commonName) == .orderedAscending }
            .map { entry in
                marineLifeRowDisplayData(
                    for: entry,
                    unitSystem: unitSystem,
                    isSighted: sightedMarineLifeUUIDs.contains(entry.uuid)
                )
            }
    }

    nonisolated static func marineLifeRowDisplayData(
        for entry: MarineLifeCatalogSnapshot,
        unitSystem: DiveDisplayUnitSystem,
        isSighted: Bool
    ) -> MarineLifeRowDisplayData {
        MarineLifeRowDisplayData(
            marineLifeUUID: entry.uuid,
            displayName: entry.commonName,
            trailingLabel: listTrailingLabel(for: entry),
            detailLine: listDetailLine(
                scientificName: entry.scientificName,
                sizeDepthLine: sizeDepthLine(for: entry, unitSystem: unitSystem)
            ),
            isSighted: isSighted
        )
    }

    nonisolated static func listTrailingLabel(for entry: MarineLifeCatalogSnapshot) -> String {
        let sub = FieldGuideTaxonomy.subcategoryTitle(for: entry)
        if sub != "—" { return sub }
        return FieldGuideTaxonomy.categoryTitle(for: entry)
    }

    nonisolated static func listTrailingLabel(category: String) -> String {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    nonisolated static func listDetailLine(scientificName: String, sizeDepthLine: String) -> String {
        let scientific = scientificName.trimmingCharacters(in: .whitespacesAndNewlines)
        let sizeDepth = sizeDepthLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if scientific.isEmpty { return sizeDepth }
        if sizeDepth.isEmpty { return scientific }
        return "\(scientific) · \(sizeDepth)"
    }

    /// Logbook rows for species **Tagged dives** pager (newest dive first).
    static func sightedDiveRowDisplayData(
        activityIDs: [UUID],
        activities: [DiveActivity],
        unitSystem: DiveDisplayUnitSystem,
        useChronologicalNumbers: Bool = false,
        numberingActivities: [DiveActivity]? = nil
    ) -> [DiveLogbookRowDisplayData] {
        guard !activityIDs.isEmpty else { return [] }

        let idSet = Set(activityIDs)
        let sightedActivities = activities
            .filter { idSet.contains($0.id) }
            .sorted { $0.startTime > $1.startTime }

        return DiveLogbookDisplay.rowData(
            activities: sightedActivities,
            unitSystem: unitSystem,
            duplicateIds: [],
            useChronologicalNumbers: useChronologicalNumbers,
            numberingActivities: numberingActivities
        )
    }

    /// Resolves tagged dive activities for the species detail sheet (newest dive first).
    nonisolated static func sightedActivityLinks(
        activityIDs: [UUID],
        activities: [DiveActivitySightingLinkSnapshot]
    ) -> [SightedActivityLinkData] {
        guard !activityIDs.isEmpty else { return [] }

        let idSet = Set(activityIDs)
        return activities
            .filter { idSet.contains($0.id) }
            .sorted { $0.startTime > $1.startTime }
            .map { activity in
                SightedActivityLinkData(
                    id: activity.id,
                    title: LogbookActivityRow.displayName(resolvedSiteName: activity.resolvedSiteName),
                    dateText: DiveActivityTimePresentation.formatDateOnly(
                        activity.startTime,
                        timeZoneOffsetSeconds: activity.timeZoneOffsetSeconds
                    )
                )
            }
    }

    nonisolated static func sizeDepthLine(for entry: MarineLifeCatalogSnapshot, unitSystem: DiveDisplayUnitSystem) -> String {
        let sizeLine = sizeRangeLine(
            minMeters: entry.minSizeMeters,
            maxMeters: entry.maxSizeMeters,
            unitSystem: unitSystem
        )
        let depthLine = depthLine(
            minMeters: entry.minDepthMeters,
            maxMeters: entry.maxDepthMeters,
            avgMeters: entry.avgDepthMeters,
            unitSystem: unitSystem
        )
        if sizeLine.isEmpty { return depthLine }
        if depthLine.isEmpty { return sizeLine }
        return "\(sizeLine) · \(depthLine)"
    }

    nonisolated static func sizeRangeLine(
        minMeters: Double,
        maxMeters: Double,
        unitSystem: DiveDisplayUnitSystem
    ) -> String {
        guard minMeters > 0 || maxMeters > 0 else { return "" }
        if minMeters > 0, maxMeters > 0, abs(minMeters - maxMeters) > 0.001 {
            return "\(DiveQuantityFormatting.length(meters: minMeters, system: unitSystem))–\(DiveQuantityFormatting.length(meters: maxMeters, system: unitSystem))"
        }
        let value = maxMeters > 0 ? maxMeters : minMeters
        return "up to \(DiveQuantityFormatting.length(meters: value, system: unitSystem))"
    }

    nonisolated static func depthLine(
        minMeters: Double,
        maxMeters: Double,
        avgMeters: Double,
        unitSystem: DiveDisplayUnitSystem
    ) -> String {
        if minMeters > 0, maxMeters > 0, abs(minMeters - maxMeters) > 0.001 {
            return DiveQuantityFormatting.fieldGuideDepthRange(
                minMeters: minMeters,
                maxMeters: maxMeters,
                system: unitSystem
            )
        }
        return typicalDepthLine(meters: avgMeters > 0 ? avgMeters : max(minMeters, maxMeters), unitSystem: unitSystem)
    }

    nonisolated static func typicalDepthLine(meters: Double, unitSystem: DiveDisplayUnitSystem) -> String {
        guard meters > 0 else { return "" }
        return "avg \(DiveQuantityFormatting.fieldGuideDepth(meters: meters, system: unitSystem))"
    }
}
