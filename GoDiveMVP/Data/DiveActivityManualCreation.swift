import Foundation
import SwiftData

/// User-confirmed values from **Add activity → Manual entry** before a dive row is inserted.
struct ManualDiveEntryInput: Equatable, Sendable {
    var startTime: Date
    /// Optional dive site label (stored on **`siteName`**).
    var siteNameText: String
}

/// Creates and persists a blank **Manual** **`DiveActivity`** from **Add activity → Manual entry**.
enum DiveActivityManualCreation {

    static let successMessagePrefix = "Manual dive created"

    /// Trims **`siteNameText`**; **`nil`** when empty.
    nonisolated static func sanitizedSiteName(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Blank dive for in-app editing — **Manual** source, no profile, no **`sourceDiveId`**.
    nonisolated static func makeBlankActivity(
        startTime: Date = Date(),
        siteName: String? = nil,
        defaultTank: DefaultTankSpecification = DiveActivityTankDefaults.resolvedSpecification()
    ) -> DiveActivity {
        DiveActivity(
            source: .manual,
            sourceDiveId: nil,
            startTime: startTime,
            durationMinutes: 0,
            maxDepthMeters: 0,
            siteName: siteName,
            tankMaterial: defaultTank.materialLabel,
            tankVolumeDescription: defaultTank.storedDescription
        )
    }

    nonisolated static func makeBlankActivity(from input: ManualDiveEntryInput) -> DiveActivity {
        makeBlankActivity(
            startTime: input.startTime,
            siteName: sanitizedSiteName(input.siteNameText)
        )
    }

    /// Inserts the dive for the signed-in profile (dive **#**, auto-add gear, save).
    static func persist(
        _ activity: DiveActivity,
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
            try DiveActivityEquipmentAssociation.applyAutoAdd(
                to: activity,
                ownerProfileID: owner.id,
                modelContext: modelContext
            )
            try modelContext.save()
            try DiveActivityDiveNumbering.applyAutomaticSequentialRenumberIfNeeded(modelContext: modelContext)
            return DiveFileImportOutcome(
                userMessage: "\(successMessagePrefix).",
                primaryInsertedDiveId: activity.id
            )
        } catch {
            return DiveFileImportOutcome(userMessage: error.localizedDescription, primaryInsertedDiveId: nil)
        }
    }
}
