import Foundation
import SwiftData

/// Adopts local dive-log rows that would otherwise leave Home / Logbook empty for the signed-in profile.
///
/// Handles:
/// - **`ownerProfileID == nil`** (pre-account imports) via existing **`claimUnowned*`**
/// - **Missing owner UUID** (profile row deleted / never imported)
/// - **Stranded sole-account rows** owned by another local profile that is not a different Apple ID
///   (SIWA mint / blank-id twin) — never steals from another live Apple account on a shared device
enum AccountSessionLocalOwnershipHealing: Sendable {

    @discardableResult
    nonisolated static func healIfNeeded(
        for owner: UserProfile,
        modelContext: ModelContext
    ) throws -> Int {
        var healed = 0
        // Missing-profile UUIDs first — otherwise **`DiveUnownedClaimGate`** treats them as
        // "other owners" and refuses to claim remaining **`nil`** rows.
        healed += try reassignMissingOwnerProfileRows(to: owner, modelContext: modelContext)

        // Evaluate the claim gate once (count-only) so we do not re-scan on each claim helper.
        let claimDecision = try DiveUnownedClaimGate.decision(
            ownerID: owner.id,
            modelContext: modelContext
        )
        if claimDecision == .claim {
            healed += try DiveActivityOwnership.claimUnownedDives(
                for: owner,
                modelContext: modelContext,
                force: true
            )
            healed += try SnorkelActivityOwnership.claimUnownedSnorkels(
                for: owner,
                modelContext: modelContext,
                force: true
            )
            healed += try DiveBuddyOwnership.claimUnownedBuddies(
                for: owner,
                modelContext: modelContext,
                force: true
            )
        }

        healed += try adoptStrandedActivitiesIfSoleLocalAccount(for: owner, modelContext: modelContext)
        return healed
    }

    /// Remaps rows whose **`ownerProfileID`** points at a UUID with no **`UserProfile`** row.
    @discardableResult
    nonisolated static func reassignMissingOwnerProfileRows(
        to owner: UserProfile,
        modelContext: ModelContext
    ) throws -> Int {
        let ownerID = owner.id
        let knownIDs = Set(try modelContext.fetch(FetchDescriptor<UserProfile>()).map(\.id))

        // Healthy single-account stores own every row — skip materializing the full logbook.
        let foreignDiveCount = try modelContext.fetchCount(
            FetchDescriptor<DiveActivity>(
                predicate: #Predicate { dive in
                    dive.ownerProfileID != nil && dive.ownerProfileID != ownerID
                }
            )
        )
        let foreignSnorkelCount = try modelContext.fetchCount(
            FetchDescriptor<SnorkelActivity>(
                predicate: #Predicate { snorkel in
                    snorkel.ownerProfileID != nil && snorkel.ownerProfileID != ownerID
                }
            )
        )
        let foreignBuddyCount = try modelContext.fetchCount(
            FetchDescriptor<DiveBuddy>(
                predicate: #Predicate { buddy in
                    buddy.ownerProfileID != nil && buddy.ownerProfileID != ownerID
                }
            )
        )
        guard foreignDiveCount + foreignSnorkelCount + foreignBuddyCount > 0 else {
            return 0
        }

        var count = 0

        if foreignDiveCount > 0 {
            let dives = try modelContext.fetch(
                FetchDescriptor<DiveActivity>(
                    predicate: #Predicate { dive in
                        dive.ownerProfileID != nil && dive.ownerProfileID != ownerID
                    }
                )
            )
            for dive in dives {
                guard let oid = dive.ownerProfileID, !knownIDs.contains(oid) else { continue }
                DiveActivityOwnership.assignOwner(owner, to: dive)
                count += 1
            }
        }

        if foreignSnorkelCount > 0 {
            let snorkels = try modelContext.fetch(
                FetchDescriptor<SnorkelActivity>(
                    predicate: #Predicate { snorkel in
                        snorkel.ownerProfileID != nil && snorkel.ownerProfileID != ownerID
                    }
                )
            )
            for snorkel in snorkels {
                guard let oid = snorkel.ownerProfileID, !knownIDs.contains(oid) else { continue }
                SnorkelActivityOwnership.assignOwner(owner, to: snorkel)
                count += 1
            }
        }

        if foreignBuddyCount > 0 {
            let buddies = try modelContext.fetch(
                FetchDescriptor<DiveBuddy>(
                    predicate: #Predicate { buddy in
                        buddy.ownerProfileID != nil && buddy.ownerProfileID != ownerID
                    }
                )
            )
            for buddy in buddies {
                guard let oid = buddy.ownerProfileID, !knownIDs.contains(oid) else { continue }
                DiveBuddyOwnership.assignOwner(owner, to: buddy)
                count += 1
            }
        }

        if count > 0 {
            try modelContext.save()
        }
        return count
    }

    /// When the session owns nothing but the store has activities, and no *other Apple account*
    /// owns those rows, adopt them onto the session profile (heals blank-id / SIWA-mint twins).
    @discardableResult
    nonisolated static func adoptStrandedActivitiesIfSoleLocalAccount(
        for owner: UserProfile,
        modelContext: ModelContext
    ) throws -> Int {
        let ownerID = owner.id
        let ownedDiveCount = try modelContext.fetchCount(
            FetchDescriptor<DiveActivity>(predicate: #Predicate { $0.ownerProfileID == ownerID })
        )
        let ownedSnorkelCount = try modelContext.fetchCount(
            FetchDescriptor<SnorkelActivity>(predicate: #Predicate { $0.ownerProfileID == ownerID })
        )
        guard ownedDiveCount + ownedSnorkelCount == 0 else { return 0 }

        let foreignDiveCount = try modelContext.fetchCount(
            FetchDescriptor<DiveActivity>(
                predicate: #Predicate { dive in
                    dive.ownerProfileID != nil && dive.ownerProfileID != ownerID
                }
            )
        )
        let foreignSnorkelCount = try modelContext.fetchCount(
            FetchDescriptor<SnorkelActivity>(
                predicate: #Predicate { snorkel in
                    snorkel.ownerProfileID != nil && snorkel.ownerProfileID != ownerID
                }
            )
        )
        guard foreignDiveCount + foreignSnorkelCount > 0 else { return 0 }

        let ownerApple = owner.appleUserIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let profiles = try modelContext.fetch(FetchDescriptor<UserProfile>())
        for profile in profiles where profile.id != ownerID {
            let otherApple = profile.appleUserIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !otherApple.isEmpty, otherApple != ownerApple else { continue }
            let otherID = profile.id
            let otherOwnsDives = try modelContext.fetchCount(
                FetchDescriptor<DiveActivity>(predicate: #Predicate { $0.ownerProfileID == otherID })
            ) > 0
            let otherOwnsSnorkels = try modelContext.fetchCount(
                FetchDescriptor<SnorkelActivity>(predicate: #Predicate { $0.ownerProfileID == otherID })
            ) > 0
            if otherOwnsDives || otherOwnsSnorkels {
                return 0
            }
        }

        let dives = try modelContext.fetch(
            FetchDescriptor<DiveActivity>(
                predicate: #Predicate { dive in
                    dive.ownerProfileID != nil && dive.ownerProfileID != ownerID
                }
            )
        )
        let snorkels = try modelContext.fetch(
            FetchDescriptor<SnorkelActivity>(
                predicate: #Predicate { snorkel in
                    snorkel.ownerProfileID != nil && snorkel.ownerProfileID != ownerID
                }
            )
        )
        let buddies = try modelContext.fetch(
            FetchDescriptor<DiveBuddy>(
                predicate: #Predicate { buddy in
                    buddy.ownerProfileID != nil && buddy.ownerProfileID != ownerID
                }
            )
        )

        var count = 0
        for dive in dives {
            DiveActivityOwnership.assignOwner(owner, to: dive)
            count += 1
        }
        for snorkel in snorkels {
            SnorkelActivityOwnership.assignOwner(owner, to: snorkel)
            count += 1
        }
        for buddy in buddies {
            DiveBuddyOwnership.assignOwner(owner, to: buddy)
            count += 1
        }
        if count > 0 {
            try modelContext.save()
        }
        return count
    }
}
