import Foundation
import SwiftData

/// Loads bundled JSON fixtures into SwiftData. **MVP / mock only** — remove or replace when live imports exist.
enum MockDataSeeder {
    static func seedIfNeeded(
        context: ModelContext,
        resourceName: String,
        resourceExtension: String = "json"
    ) throws {
        try seedDiveSitesIfNeeded(
            context: context,
            resourceName: "divesites_sample",
            resourceExtension: resourceExtension
        )
        try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)

        let activityDTOs = try MockDiveDataLoader.loadActivities(
            resourceName: resourceName,
            resourceExtension: resourceExtension
        )

        if activityDTOs.isEmpty {
            try DiveActivityDiveNumbering.backfillMissingDiveNumbers(modelContext: context)
            try DiveActivityDiveNumbering.applyAutomaticSequentialRenumberIfNeeded(modelContext: context)
            try context.save()
            return
        }

        let descriptor = FetchDescriptor<DiveActivity>()
        let existingCount = try context.fetchCount(descriptor)

        if existingCount == 0 {
            for dto in activityDTOs {
                insertActivityFromFixture(dto, context: context)
            }
        } else {
            try syncBundledFixtureFieldsIfNeeded(activityDTOs: activityDTOs, context: context)
        }

        try DiveActivityDiveNumbering.backfillMissingDiveNumbers(modelContext: context)
        try DiveActivityDiveNumbering.applyAutomaticSequentialRenumberIfNeeded(modelContext: context)
        try context.save()
    }

    /// Inserts catalog `DiveSite` rows from bundled JSON when missing (matched by `id`).
    private static func seedDiveSitesIfNeeded(
        context: ModelContext,
        resourceName: String,
        resourceExtension: String
    ) throws {
        let dtos = try MockDiveDataLoader.loadDiveSites(
            resourceName: resourceName,
            resourceExtension: resourceExtension
        )
        guard !dtos.isEmpty else { return }

        let existing = try context.fetch(FetchDescriptor<DiveSite>())
        var existingIds = Set(existing.map(\.id))

        for dto in dtos {
            let site = DiveSiteMapper.map(dto)
            if existingIds.contains(site.id) {
                continue
            }
            context.insert(site)
            existingIds.insert(site.id)
        }
    }

    /// Inserts the activity and each `DiveBuddyTag` (SwiftData requires related tags to be inserted explicitly).
    private static func insertActivityFromFixture(_ dto: DiveActivityDTO, context: ModelContext) {
        let activity = DiveActivityMapper.map(dto, modelContext: context)
        context.insert(activity)
        for tag in activity.buddies {
            context.insert(tag)
        }
        if let sites = try? context.fetch(FetchDescriptor<DiveSite>()) {
            DiveActivitySiteAssociation.applyBestMatch(
                to: activity,
                catalogSites: sites,
                modelContext: context
            )
        }
    }

    /// For dives already in the store: matches rows by JSON `id` and reapplies `notes` / missing `buddies` from the fixture. Rows without `id` are skipped here (insert path still works via mapper).
    private static func syncBundledFixtureFieldsIfNeeded(
        activityDTOs: [DiveActivityDTO],
        context: ModelContext
    ) throws {
        let activities = try context.fetch(FetchDescriptor<DiveActivity>())
        for dto in activityDTOs {
            guard let dtoId = dto.id else { continue }
            guard let activity = activities.first(where: { $0.id == dtoId }) else { continue }

            if activity.notes != dto.notes {
                activity.notes = dto.notes
            }

            guard activity.buddies.isEmpty else { continue }
            guard let buddyDTOs = dto.buddies, !buddyDTOs.isEmpty else { continue }

            let tags = buddyDTOs.compactMap { buddyDTO in
                DiveBuddyTagging.makeTag(
                    displayName: buddyDTO.displayName,
                    tagID: buddyDTO.id ?? UUID(),
                    dive: activity,
                    owner: activity.owner,
                    modelContext: context
                )
            }
            activity.buddies = tags
            for tag in tags {
                context.insert(tag)
            }
        }
    }
}
