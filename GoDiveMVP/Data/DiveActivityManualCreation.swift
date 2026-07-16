import Foundation
import SwiftData

/// How **Add activity → Manual entry** should attach a catalog dive site when the dive is created.
enum ManualDiveEntrySiteSelection: Equatable, Sendable {
    case none
    case existingSite(id: UUID)
    case newSite(DiveSiteFormDraft)
}

/// User-confirmed values from **Add activity → Manual entry** before a dive row is inserted.
struct ManualDiveEntryInput: Equatable, Sendable {
    var startTime: Date
    var siteSelection: ManualDiveEntrySiteSelection = .none
}

/// Creates and persists a blank **Manual** **`DiveActivity`** from **Add activity → Manual entry**.
enum DiveActivityManualCreation {

    nonisolated static let cancelAccessibilityIdentifier = "ManualDiveEntry.Cancel"
    nonisolated static let doneAccessibilityIdentifier = "ManualDiveEntry.Done"

    static let successMessagePrefix = "Manual dive created"

    /// Blank dive for in-app editing — **Manual** source, no profile, no **`sourceDiveId`**.
    nonisolated static func makeBlankActivity(
        startTime: Date = Date(),
        siteName: String? = nil,
        defaultTank: DefaultTankSpecification = DiveActivityTankDefaults.resolvedSpecification(),
        userDefaults: UserDefaults = .standard
    ) -> DiveActivity {
        let activity = DiveActivity(
            source: .manual,
            sourceDiveId: nil,
            startTime: startTime,
            timeZoneOffsetSeconds: TimeZone.current.secondsFromGMT(),
            durationMinutes: 0,
            maxDepthMeters: 0,
            siteName: siteName,
            tankMaterial: defaultTank.materialLabel,
            tankVolumeDescription: defaultTank.storedDescription
        )
        DiveActivityDiverWeightDefaults.applyImportDefaults(to: activity, userDefaults: userDefaults)
        return activity
    }

    nonisolated static func makeBlankActivity(from input: ManualDiveEntryInput) -> DiveActivity {
        makeBlankActivity(startTime: input.startTime)
    }

    /// Inserts the dive for the signed-in profile (dive **#**, auto-add gear, save).
    static func persist(
        _ activity: DiveActivity,
        siteSelection: ManualDiveEntrySiteSelection = .none,
        modelContext: ModelContext,
        owner: UserProfile? = nil
    ) -> DiveFileImportOutcome {
        guard activity.source == .manual else {
            return DiveFileImportOutcome(
                userMessage: "Only manual dives can be created this way.",
                primaryInsertedDiveId: nil
            )
        }
        do {
            guard let owner = owner ?? AccountSession.shared.currentProfile else {
                return DiveFileImportOutcome(
                    userMessage: "Sign in to add dives.",
                    primaryInsertedDiveId: nil
                )
            }
            activity.sourceDiveId = nil
            try DiveActivityDiveNumbering.assignNextDiveNumberChainedAfterNewest(for: activity, modelContext: modelContext)
            DiveActivityOwnership.assignOwner(owner, to: activity)
            modelContext.insert(activity)
            try applySiteSelection(siteSelection, to: activity, modelContext: modelContext)
            try DiveActivityEquipmentAssociation.applyAutoAdd(
                to: activity,
                ownerProfileID: owner.id,
                modelContext: modelContext
            )
            try modelContext.save()
            try DiveActivityDiveNumbering.applyAutomaticSequentialRenumberIfNeeded(modelContext: modelContext)
            try DiveTripActivityLinking.applyAutoLinkForOwner(
                ownerProfileID: owner.id,
                modelContext: modelContext
            )
            return DiveFileImportOutcome(
                userMessage: "\(successMessagePrefix).",
                primaryInsertedDiveId: activity.id
            )
        } catch {
            return DiveFileImportOutcome(userMessage: error.localizedDescription, primaryInsertedDiveId: nil)
        }
    }

    private static func applySiteSelection(
        _ selection: ManualDiveEntrySiteSelection,
        to activity: DiveActivity,
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
            DiveActivitySiteAssociation.link(activity, to: site)
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
