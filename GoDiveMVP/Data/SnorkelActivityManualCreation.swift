import Foundation
import SwiftData

/// User-confirmed values from **Add snorkel → Manual entry** before a snorkel row is inserted.
struct ManualSnorkelEntryInput: Equatable, Sendable {
    var startTime: Date
    var siteSelection: ManualDiveEntrySiteSelection = .none
}

/// Creates and persists a blank **Manual** **`SnorkelActivity`** from **Add snorkel → Manual entry**.
enum SnorkelActivityManualCreation {

    nonisolated static let cancelAccessibilityIdentifier = "ManualSnorkelEntry.Cancel"
    nonisolated static let doneAccessibilityIdentifier = "ManualSnorkelEntry.Done"

    static let successMessagePrefix = "Manual snorkel created"

    /// Blank snorkel for in-app editing — **Manual** source, no FIT id, no swim/heart-rate samples.
    nonisolated static func makeBlankActivity(
        startTime: Date = Date(),
        userDefaults: UserDefaults = .standard
    ) -> SnorkelActivity {
        let activity = SnorkelActivity(
            source: .manual,
            sourceActivityId: nil,
            startTime: startTime,
            timeZoneOffsetSeconds: TimeZone.current.secondsFromGMT(),
            durationMinutes: 0
        )
        ActivityFriendShareConfiguration.seedBuddyShareDefaultsOnNewActivity(activity, userDefaults: userDefaults)
        return activity
    }

    nonisolated static func makeBlankActivity(from input: ManualSnorkelEntryInput) -> SnorkelActivity {
        makeBlankActivity(startTime: input.startTime)
    }

    /// Inserts the snorkel for the signed-in profile (owner, optional site, save).
    static func persist(
        _ activity: SnorkelActivity,
        siteSelection: ManualDiveEntrySiteSelection = .none,
        modelContext: ModelContext,
        owner: UserProfile? = nil
    ) -> SnorkelFileImportOutcome {
        guard activity.source == .manual else {
            return SnorkelFileImportOutcome(
                userMessage: "Only manual snorkels can be created this way.",
                primaryInsertedActivityId: nil
            )
        }
        do {
            guard let owner = owner ?? AccountSession.shared.currentProfile else {
                return SnorkelFileImportOutcome(
                    userMessage: "Sign in to add snorkel sessions.",
                    primaryInsertedActivityId: nil
                )
            }
            activity.sourceActivityId = nil
            SnorkelActivityOwnership.assignOwner(owner, to: activity)
            modelContext.insert(activity)
            try applySiteSelection(siteSelection, to: activity, modelContext: modelContext)
            try modelContext.save()
            let snorkelID = activity.id
            Task { @MainActor in
                var descriptor = FetchDescriptor<SnorkelActivity>(
                    predicate: #Predicate<SnorkelActivity> { $0.id == snorkelID }
                )
                descriptor.fetchLimit = 1
                if let snorkel = try? modelContext.fetch(descriptor).first {
                    await OntologySiteReportContributionSync.syncAfterSnorkelPersisted(
                        snorkel: snorkel,
                        modelContext: modelContext
                    )
                }
            }
            return SnorkelFileImportOutcome(
                userMessage: "\(successMessagePrefix).",
                primaryInsertedActivityId: activity.id
            )
        } catch {
            return SnorkelFileImportOutcome(
                userMessage: error.localizedDescription,
                primaryInsertedActivityId: nil
            )
        }
    }

    private static func applySiteSelection(
        _ selection: ManualDiveEntrySiteSelection,
        to activity: SnorkelActivity,
        modelContext: ModelContext
    ) throws {
        switch selection {
        case .none:
            return
        case .existingSite(let siteID):
            var descriptor = FetchDescriptor<DiveSite>(
                predicate: #Predicate<DiveSite> { $0.id == siteID }
            )
            descriptor.fetchLimit = 1
            guard let site = try modelContext.fetch(descriptor).first else { return }
            DiveActivitySiteAssociation.link(activity, to: site, modelContext: modelContext)
        case .newSite(let draft):
            guard let siteName = DiveSiteFormValidation.sanitizedSiteName(draft.siteName) else { return }
            let parsed = DiveSiteFormValidation.parsedCoordinate(
                latitudeText: draft.latitudeText,
                longitudeText: draft.longitudeText
            )
            _ = try DiveActivitySiteAssociation.createSiteAndLink(
                to: activity,
                siteName: siteName,
                country: DiveSiteFormValidation.sanitizedPlaceField(draft.country),
                region: DiveSiteFormValidation.sanitizedPlaceField(draft.region),
                bodyOfWater: DiveSiteFormValidation.sanitizedPlaceField(draft.bodyOfWater),
                latCoords: parsed?.latitude,
                longCoords: parsed?.longitude,
                waterType: draft.waterType,
                modelContext: modelContext,
                persistImmediately: false
            )
        }
    }
}
