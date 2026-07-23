import SwiftData
import SwiftUI

/// Pushed buddy / friend profile from **`DiveBuddiesListView`** (single build site — not per-row **`NavigationLink`**).
struct BuddiesListNavigationDestinationView: View {
    let route: BuddiesListNavigationRoute

    var body: some View {
        switch route {
        case .friend(let edge):
            FriendProfileView(friend: edge)
                .onAppear {
                    BuddiesListNavigationDiagnostics.logListDestinationAppear(
                        destination: "FriendProfile",
                        isFriend: true,
                        sharedDiveCount: 0,
                        mapPinCount: 0
                    )
                }
        case .rosterBuddy(let buddyID):
            BuddiesListRosterBuddyDetailHost(buddyID: buddyID)
                .onAppear {
                    BuddiesListNavigationDiagnostics.logListDestinationAppear(
                        destination: "BuddyDetail",
                        isFriend: false,
                        sharedDiveCount: 0,
                        mapPinCount: 0
                    )
                }
        }
    }
}

/// Resolves roster buddy by id when the list pushes — detail is not built for off-stack rows.
struct BuddiesListRosterBuddyDetailHost: View {
    let buddyID: UUID

    @Query private var buddies: [DiveBuddy]

    init(buddyID: UUID) {
        self.buddyID = buddyID
        _buddies = Query(filter: #Predicate<DiveBuddy> { $0.id == buddyID })
    }

    var body: some View {
        if let buddy = buddies.first {
            ViewDiveBuddyDetails(buddy: buddy)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct OpenBuddiesListDetailRouteKey: EnvironmentKey {
    static let defaultValue: ((BuddiesListNavigationRoute) -> Void)? = nil
}

extension EnvironmentValues {
    /// When set (Logbook tab stack), buddy list rows append **`LogbookRoute.buddiesListDetail`** instead of local state.
    var openBuddiesListDetailRoute: ((BuddiesListNavigationRoute) -> Void)? {
        get { self[OpenBuddiesListDetailRouteKey.self] }
        set { self[OpenBuddiesListDetailRouteKey.self] = newValue }
    }
}
