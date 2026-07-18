import SwiftData
import SwiftUI

/// Resolves a dive-site detail destination by stable **`id`** (catalog **`DiveSite`** or user **`UserDiveSite`**).
struct ExploreDiveSiteDetailHost: View {
    @Environment(\.modelContext) private var modelContext

    let siteID: UUID
    let ownerProfileID: UUID?
    let onOpenDive: (UUID) -> Void

    @State private var catalogSite: DiveSite?
    @State private var userSite: UserDiveSite?
    @State private var didResolve = false

    var body: some View {
        Group {
            if let catalogSite {
                ExploreDiveSiteDetailView(
                    site: catalogSite,
                    ownerProfileID: ownerProfileID,
                    onOpenDive: onOpenDive
                )
            } else if let userSite {
                ExploreDiveSiteDetailView(
                    site: userSite,
                    ownerProfileID: ownerProfileID,
                    onOpenDive: onOpenDive
                )
            } else if didResolve {
                Text("This dive site is no longer in the catalog.")
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .padding()
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: siteID) {
            await resolveSite()
        }
    }

    @MainActor
    private func resolveSite() async {
        await Task.yield()
        if let user = try? DiveLinkedSiteResolver.existingUserDiveSite(id: siteID, modelContext: modelContext) {
            userSite = user
            catalogSite = nil
        } else if let catalog = try? DiveLinkedSiteResolver.existingCatalogDiveSite(
            id: siteID,
            modelContext: modelContext
        ) {
            catalogSite = catalog
            userSite = nil
        } else {
            catalogSite = nil
            userSite = nil
        }
        didResolve = true
    }
}
