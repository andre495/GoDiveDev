import Foundation
import SwiftData

/// On-device snapshot for Settings — whether private iCloud mirroring is enabled and how many
/// activities are attached to the signed-in profile vs elsewhere in the local store.
enum GoDiveCloudKitDiveLogLocalStatus: Sendable {

    enum PrivateSyncState: String, Sendable, Equatable {
        case enabled
        case disabled
        case unknown
    }

    struct Snapshot: Sendable, Equatable {
        let privateSync: PrivateSyncState
        let sessionProfileDiveCount: Int
        let sessionProfileSnorkelCount: Int
        let totalDiveCount: Int
        let totalSnorkelCount: Int
        let appleIDProfileCount: Int
        let activitiesOnOtherProfilesForSameAppleID: Int
        let lastOpenDiagnosticLine: String?
        let lastCloudKitOpenError: String?
    }

    nonisolated static func snapshot(
        sessionProfileID: UUID?,
        appleUserIdentifier: String?,
        modelContext: ModelContext,
        defaults: UserDefaults = .standard
    ) throws -> Snapshot {
        let privateSync = readPrivateSyncState(defaults: defaults)
        let totalDives = try modelContext.fetchCount(FetchDescriptor<DiveActivity>())
        let totalSnorkels = try modelContext.fetchCount(FetchDescriptor<SnorkelActivity>())

        guard let sessionProfileID else {
            return Snapshot(
                privateSync: privateSync,
                sessionProfileDiveCount: 0,
                sessionProfileSnorkelCount: 0,
                totalDiveCount: totalDives,
                totalSnorkelCount: totalSnorkels,
                appleIDProfileCount: 0,
                activitiesOnOtherProfilesForSameAppleID: 0,
                lastOpenDiagnosticLine: readLastDiagnosticLine(),
                lastCloudKitOpenError: AppSwiftDataDualStoreFactory.lastCloudKitFallbackErrorMessage(defaults: defaults)
            )
        }

        let sessionID = sessionProfileID
        let sessionDives = try modelContext.fetchCount(
            FetchDescriptor<DiveActivity>(
                predicate: #Predicate { $0.ownerProfileID == sessionID }
            )
        )
        let sessionSnorkels = try modelContext.fetchCount(
            FetchDescriptor<SnorkelActivity>(
                predicate: #Predicate { $0.ownerProfileID == sessionID }
            )
        )

        let trimmedAppleID = appleUserIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var profileCount = 0
        var otherProfileActivityCount = 0
        if !trimmedAppleID.isEmpty {
            let appleID = trimmedAppleID
            let profiles = try modelContext.fetch(
                FetchDescriptor<UserProfile>(
                    predicate: #Predicate { $0.appleUserIdentifier == appleID }
                )
            )
            profileCount = profiles.count
            let otherIDs = profiles.map(\.id).filter { $0 != sessionProfileID }
            for otherID in otherIDs {
                otherProfileActivityCount += try modelContext.fetchCount(
                    FetchDescriptor<DiveActivity>(
                        predicate: #Predicate { $0.ownerProfileID == otherID }
                    )
                )
                otherProfileActivityCount += try modelContext.fetchCount(
                    FetchDescriptor<SnorkelActivity>(
                        predicate: #Predicate { $0.ownerProfileID == otherID }
                    )
                )
            }
        }

        return Snapshot(
            privateSync: privateSync,
            sessionProfileDiveCount: sessionDives,
            sessionProfileSnorkelCount: sessionSnorkels,
            totalDiveCount: totalDives,
            totalSnorkelCount: totalSnorkels,
            appleIDProfileCount: profileCount,
            activitiesOnOtherProfilesForSameAppleID: otherProfileActivityCount,
            lastOpenDiagnosticLine: readLastDiagnosticLine(),
            lastCloudKitOpenError: AppSwiftDataDualStoreFactory.lastCloudKitFallbackErrorMessage(defaults: defaults)
        )
    }

    nonisolated static func readPrivateSyncState(defaults: UserDefaults = .standard) -> PrivateSyncState {
        guard let enabled = defaults.object(
            forKey: AppSwiftDataDualStoreFactory.lastCloudKitSyncEnabledDefaultsKey
        ) as? Bool else {
            return .unknown
        }
        return enabled ? .enabled : .disabled
    }

    nonisolated static func readLastDiagnosticLine() -> String? {
        guard let root = try? AppSwiftDataDualStoreFactory.defaultRootDirectory() else { return nil }
        let path = root.appendingPathComponent(AppSwiftDataDualStoreFactory.cloudKitDiagnosticsFileName)
        guard let text = try? String(contentsOf: path, encoding: .utf8) else { return nil }
        return text
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .last { !$0.isEmpty }
    }
}
