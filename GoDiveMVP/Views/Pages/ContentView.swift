//
//  ContentView.swift
//  GoDiveMVP
//
//  Created by André Dugas on 4/1/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(AccountSession.self) private var accountSession
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppUserSettings.useImperialDisplayUnitsKey) private var useImperialDisplayUnits = true

    /// Selection binding is required for tab re-tap scroll-to-top / pop-to-root (see Apple Developer Forums thread 773497).
    @State private var selectedTab: RootTab = .home
    /// Live selection for tab content (bubbles / warm-up) — see **`RootTabSelectionStore`**.
    @State private var rootTabSelectionStore = RootTabSelectionStore()
    @State private var searchQuery = ""
    @State private var searchContextTokens: [GlobalSearchPresentation.ContextToken] = []
    @State private var logbookTabSelectionGeneration = 0
    @State private var pendingLogbookRoute: LogbookRoute?
    @State private var pendingHomeRoute: HomeRoute?
    @State private var showsActivityDeleteSuccessCheckmark = false
    @State private var activityDeleteSuccessHideTask: Task<Void, Never>?

    var body: some View {
        // Prefer `$selectedTab` over a custom Binding — iOS 26 TabView has failed to call
        // custom setters while still changing the visible UIKit tab.
        TabView(selection: $selectedTab) {
            // Do **not** wrap tabs in LazyRootTabContent: iOS 26 TabView can freeze unselected
            // tab bodies, so Color.clear placeholders never swap after the first tab change.
            // Idle-tab cost is cut via selection-gated catalog `.task`s / dive bridges instead.
            Tab("Home", systemImage: "house", value: RootTab.home) {
                LogOverviewView(
                    ownerProfileID: accountSession.currentProfile?.id,
                    pendingRoute: $pendingHomeRoute
                )
                    .id(accountSession.currentProfile?.id)
            }

            Tab("Logbook", systemImage: "book.closed", value: RootTab.logbook) {
                LogbookView(
                    ownerProfileID: accountSession.currentProfile?.id,
                    pendingRoute: $pendingLogbookRoute,
                    logbookTabSelectionGeneration: logbookTabSelectionGeneration
                )
                    .id(accountSession.currentProfile?.id)
            }

            Tab("Field Guide", systemImage: "leaf", value: RootTab.fieldGuide) {
                FieldGuideView(ownerProfileID: accountSession.currentProfile?.id)
                    .id(accountSession.currentProfile?.id)
            }

            Tab("Explore", systemImage: "map", value: RootTab.explore) {
                ExploreView(ownerProfileID: accountSession.currentProfile?.id)
                    .id(accountSession.currentProfile?.id)
            }

            Tab(value: RootTab.search, role: .search) {
                GlobalSearchView(
                    ownerProfileID: accountSession.currentProfile?.id,
                    query: $searchQuery,
                    activeContextTokens: $searchContextTokens
                )
            }
        }
        .id(accountSession.currentProfile?.id)
        .accessibilityIdentifier("GoDive.RootTabs")
        .tint(AppTheme.Colors.tabSelected)
        .goDiveRootTabBarChrome()
        .modifier(TabBarMinimizeWhenNotUITesting())
        .background { RootTabBarSelectionSyncInstaller() }
        .environment(rootTabSelectionStore)
        .environment(\.diveDisplayUnitSystem, useImperialDisplayUnits ? .imperial : .metric)
        .environment(\.openDiveImport) {
            selectedTab = .logbook
            pendingLogbookRoute = .addActivity
        }
        .onAppear {
            applyRootTabSelection(selectedTab, source: "onAppear")
            startFriendShareSaveObserverIfNeeded()
            // Cold start: notification tap often sets pending stores before this view exists
            // (NC posts are lost). Flush here — do not rely only on onChange(shell).
            openAllPendingDeepLinksIfNeeded()
        }
        .onChange(of: selectedTab) { _, tab in
            applyRootTabSelection(tab, source: "swiftUI")
            if tab == .logbook {
                logbookTabSelectionGeneration += 1
            }
        }
        // Authoritative when SwiftUI selection binding stalls (device console: only logbook).
        .onReceive(NotificationCenter.default.publisher(for: .rootTabBarDidSelect)) { notification in
            guard let tab = RootTabBarSelectionSync.tab(from: notification) else { return }
            applyRootTabSelection(tab, source: "uitabbar")
            if selectedTab != tab {
                selectedTab = tab
            }
        }
        .onChange(of: accountSession.currentProfile?.id) { _, _ in
            startFriendShareSaveObserverIfNeeded()
        }
        .onChange(of: accountSession.showsMainAppShell) { _, showsMain in
            guard showsMain else { return }
            openAllPendingDeepLinksIfNeeded()
        }
        .onChange(of: accountSession.isHomeLaunchChromeReady) { _, isReady in
            guard isReady else { return }
            openAllPendingDeepLinksIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: GoDiveFirebaseCloudMessaging.openFriendsListNotification)) { _ in
            guard canOpenPendingPushDeepLinks else { return }
            selectedTab = .logbook
            pendingLogbookRoute = .friends
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: GoDiveFirebaseCloudMessaging.openBuddySharedActivityNotification
            )
        ) { _ in
            openPendingBuddySharedActivityFromPushIfNeeded()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: GoDiveFirebaseCloudMessaging.openOwnedActivityFromLikeNotification
            )
        ) { _ in
            openPendingOwnedActivityFromLikePushIfNeeded()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: GoDiveFirebaseCloudMessaging.openActivityFromMentionNotification
            )
        ) { _ in
            openPendingMentionFromPushIfNeeded()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: EquipmentServiceReminderSchedule.openEquipmentDetailNotification
            )
        ) { _ in
            openPendingEquipmentDetailFromReminderIfNeeded()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: DiveTripReminderSchedule.openTripDetailNotification
            )
        ) { _ in
            openPendingTripDetailFromReminderIfNeeded()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: GoDiveFriendInvitePostRedeemNavigation.openFriendProfileNotification
            )
        ) { _ in
            openPendingFriendProfileAfterInviteRedeemIfNeeded()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: ActivityDeleteSuccessPresentation.didDeleteNotification
            )
        ) { _ in
            handleActivityDeletedSuccessfully()
        }
        .overlay {
            if showsActivityDeleteSuccessCheckmark {
                ActivityDeleteSuccessCheckmarkOverlay()
            }
        }
    }

    private func applyRootTabSelection(_ tab: RootTab, source: String) {
        rootTabSelectionStore.selected = tab
        CrashBreadcrumbTrail.noteRootTab(tab)
        #if DEBUG
        print("[WaterBubbles] root_tab_selected=\(tab) source=\(source)")
        #endif
    }

    private func handleActivityDeletedSuccessfully() {
        selectedTab = .logbook
        showsActivityDeleteSuccessCheckmark = true
        activityDeleteSuccessHideTask?.cancel()
        activityDeleteSuccessHideTask = Task { @MainActor in
            try? await Task.sleep(for: ActivityDeleteSuccessPresentation.overlayDuration)
            guard !Task.isCancelled else { return }
            showsActivityDeleteSuccessCheckmark = false
        }
    }

    private var canOpenPendingPushDeepLinks: Bool {
        GoDiveRootPushDeepLinkFlushPresentation.canOpenPendingRoutes(
            showsMainAppShell: accountSession.showsMainAppShell,
            isHomeLaunchChromeReady: accountSession.isHomeLaunchChromeReady
        )
    }

    private func openAllPendingDeepLinksIfNeeded() {
        openPendingFriendProfileAfterInviteRedeemIfNeeded()
        openPendingBuddySharedActivityFromPushIfNeeded()
        openPendingOwnedActivityFromLikePushIfNeeded()
        openPendingMentionFromPushIfNeeded()
        openPendingEquipmentDetailFromReminderIfNeeded()
        openPendingTripDetailFromReminderIfNeeded()
    }

    private func openPendingBuddySharedActivityFromPushIfNeeded() {
        guard canOpenPendingPushDeepLinks else { return }
        guard let target = GoDiveBuddyActivityPushNavigationStore.shared.consumePendingTarget() else {
            return
        }
        selectedTab = .logbook
        pendingLogbookRoute = .buddySharedDive(
            friendUID: target.friendUID,
            diveDocumentID: target.activityID
        )
    }

    private func openPendingOwnedActivityFromLikePushIfNeeded() {
        guard canOpenPendingPushDeepLinks else { return }
        guard let target = GoDiveBuddyActivityLikedPushNavigationStore.shared.consumePendingTarget()
        else { return }
        selectedTab = .logbook
        pendingLogbookRoute = GoDiveBuddyActivityLikedPushPresentation.logbookRoute(for: target)
    }

    private func openPendingMentionFromPushIfNeeded() {
        guard canOpenPendingPushDeepLinks else { return }
        guard let target = GoDiveBuddyActivityMentionedPushNavigationStore.shared.consumePendingTarget()
        else { return }
        selectedTab = .logbook
        let currentUID = GoDiveFirebaseAuthSession.currentFirebaseUID()
        if GoDiveBuddyActivityMentionedPushPresentation.isOwnedActivity(
            target: target,
            currentFirebaseUID: currentUID
        ) {
            GoDiveOwnedActivityCommentsDeepLinkStore.shared.setPending(activityID: target.activityID)
            pendingLogbookRoute = GoDiveBuddyActivityMentionedPushPresentation.ownedLogbookRoute(
                for: target
            )
        } else {
            GoDiveOwnedActivityCommentsDeepLinkStore.shared.clear()
            pendingLogbookRoute = GoDiveBuddyActivityMentionedPushPresentation.sharedLogbookRoute(
                for: target
            )
        }
    }

    private func openPendingEquipmentDetailFromReminderIfNeeded() {
        guard canOpenPendingPushDeepLinks else { return }
        guard let equipmentID = EquipmentServiceReminderNavigationStore.shared.consumePendingEquipmentID()
        else { return }
        selectedTab = .home
        pendingHomeRoute = .equipmentDetail(equipmentID)
    }

    private func openPendingTripDetailFromReminderIfNeeded() {
        guard canOpenPendingPushDeepLinks else { return }
        guard let tripID = DiveTripReminderNavigationStore.shared.consumePendingTripID() else { return }
        selectedTab = .home
        pendingHomeRoute = .tripDetail(tripID)
    }

    private func openPendingFriendProfileAfterInviteRedeemIfNeeded() {
        guard canOpenPendingPushDeepLinks else { return }
        guard let friend = GoDiveFriendInvitePostRedeemNavigationStore.shared.consumePendingFriend() else {
            return
        }
        selectedTab = .logbook
        pendingLogbookRoute = .friendProfile(friend)
    }

    private func startFriendShareSaveObserverIfNeeded() {
        guard accountSession.isSignedIn, let ownerID = accountSession.currentProfile?.id else {
            GoDiveFriendShareRefreshCoordinator.stopObservingSaves()
            return
        }
        GoDiveFriendShareRefreshCoordinator.startObservingSaves(
            ownerProfileID: ownerID,
            modelContext: modelContext
        )
        GoDiveFriendShareProfileTrackRepublish.scheduleOneTimeRepublishIfNeeded(
            ownerProfileID: ownerID,
            modelContext: modelContext
        )
        Task {
            await GoDiveBuddyShareBackgroundUpload.resumePendingWork(
                ownerProfileID: ownerID,
                modelContext: modelContext
            )
        }
    }
}

private struct TabBarMinimizeWhenNotUITesting: ViewModifier {
    func body(content: Content) -> some View {
        if GoDiveUITestConfiguration.isActive {
            content
        } else {
            content.tabBarMinimizeBehavior(.onScrollDown)
        }
    }
}

#Preview {
    ContentView()
}
