import Foundation
import SwiftData

/// Builds Explore scope-cache snapshots on a background **`ModelContext`** so ~3k ODM
/// pin/list derivation does not run on MainActor during tab select.
enum ExploreSiteScopeCacheBackgroundBuild: Sendable {

    /// Resolves catalog / user-site persistent IDs on a private context, then runs
    /// **`ExploreSiteScopeCache.make`**. Safe to call from **`Task.detached`**.
    ///
    /// When **`logbookSiteIDs`** is empty but **`ownerProfileID`** is set, loads site IDs
    /// from owner activities here (Explore dive bridge can lag first select).
    nonisolated static func makeSnapshot(
        container: ModelContainer,
        catalogPersistentIDs: [PersistentIdentifier],
        userSitePersistentIDs: [PersistentIdentifier],
        logbookSiteIDs: Set<UUID>,
        ownerProfileID: UUID? = nil
    ) -> ExploreSiteScopeCache.Snapshot {
        let context = ModelContext(container)
        let catalog = catalogPersistentIDs.compactMap { context.model(for: $0) as? DiveSite }
        let userSites = userSitePersistentIDs.compactMap { context.model(for: $0) as? UserDiveSite }
        let resolvedLogbookSiteIDs: Set<UUID>
        if logbookSiteIDs.isEmpty, let ownerProfileID {
            resolvedLogbookSiteIDs = ownerLogbookSiteIDs(
                ownerProfileID: ownerProfileID,
                context: context
            )
        } else {
            resolvedLogbookSiteIDs = logbookSiteIDs
        }
        return ExploreSiteScopeCache.make(
            catalog: catalog,
            userSites: userSites,
            logbookSiteIDs: resolvedLogbookSiteIDs
        )
    }

    nonisolated private static func ownerLogbookSiteIDs(
        ownerProfileID: UUID,
        context: ModelContext
    ) -> Set<UUID> {
        let descriptor = FetchDescriptor<DiveActivity>(
            predicate: #Predicate<DiveActivity> { $0.ownerProfileID == ownerProfileID }
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        return Set(rows.compactMap(\.diveSiteID))
    }
}
