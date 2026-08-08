//
//  GoDiveMVPApp.swift
//  GoDiveMVP
//
//  Created by André Dugas on 4/1/26.
//

import SwiftData
import SwiftUI
import UIKit

@main
struct GoDiveMVPApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(GoDiveGoogleMapsAppDelegate.self) private var googleMapsAppDelegate
    #endif

    @State private var accountSession = AccountSession.shared
    @State private var productionContainer: ModelContainer?

    init() {
        // Firebase configure stays in GoDiveGoogleMapsAppDelegate (required before FCM
        // delegate wiring). Avoid a second configureIfNeeded here — it is idempotent but
        // still touches main-thread plist I/O when called before the delegate runs.
        AppLaunchTimelineLog.processStart()
        AppUserSettings.registerDefaultValues()
        guard GoDiveUITestConfiguration.isActive else {
            AppModelContainer.beginLoadingProductionIfNeeded()
            return
        }
        UIView.setAnimationsEnabled(false)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if GoDiveUITestConfiguration.isActive {
                    GoDiveUITestRootView()
                } else if let container = productionContainer {
                    ProductionAppRoot(
                        container: container,
                        onReplaceContainer: { productionContainer = $0 },
                        accountSession: accountSession
                    )
                    .environment(AppNetworkConnectivityMonitor.shared)
                } else {
                    AppLaunchOverlay()
                        .task { productionContainer = await AppModelContainer.loadProduction() }
                }
            }
            .onAppear {
                AppLaunchFirstFrameProbe.armIfNeeded()
            }
        }
    }

}

/// Production shell — scene lifecycle clears Home media warm caches when the app backgrounds.
private struct ProductionAppRoot: View {
    let container: ModelContainer
    let onReplaceContainer: (ModelContainer) -> Void
    @Bindable var accountSession: AccountSession
    @Environment(\.scenePhase) private var scenePhase
    @State private var didRunPostSignInCloudKitReconnect = false
    @State private var isSessionRestoreAllowed = false

    var body: some View {
        AppSessionRootView(isSessionRestoreAllowed: isSessionRestoreAllowed)
            .environment(accountSession)
            .modelContainer(container)
            .task(id: ObjectIdentifier(container)) {
                accountSession.registerActiveModelContainer(container)
                accountSession.cloudKitContainerReconnectHandler = {
                    await performModelContainerCloudKitReconnect()
                }
                clearStalePendingCloudKitReconnectIfAlreadyEnabled()
                // Allow session restore immediately — CloudKit kickstart must not serialize Gate 2.
                isSessionRestoreAllowed = true
                // Kick after Home chrome is ready (see onChange below) so main-context
                // fetchCounts do not contend with Gate 2 restore + Gate 3 @Query.
            }
            .onChange(of: scenePhase) { _, phase in
                CrashReportingService.updateSessionPhase(phase)
                if phase == .active {
                    AccountSessionCloudKitIdentityObserver.reconcileOnForegroundIfNeeded(container: container)
                    GoDiveCloudKitBackgroundSync.scheduleNextOpportunities()
                    GoDiveCloudKitForegroundImportWindow.runIfNeeded(
                        container: container,
                        ownerProfileID: accountSession.currentProfile?.id,
                        appleUserIdentifier: accountSession.currentProfile?.appleUserIdentifier
                            ?? GoDiveKeychainStore.string(for: .lastAppleUserIdentifier)
                    )
                    Task {
                        await GoDiveBuddyActivityPushPreferenceSync.uploadCurrentPreference()
                        await GoDiveFirebaseCloudMessaging.registerForFriendInvitePushesIfNeeded()
                    }
                    if let ownerID = accountSession.currentProfile?.id {
                        Task {
                            await GoDiveBuddyShareBackgroundUpload.resumePendingWork(
                                ownerProfileID: ownerID,
                                modelContext: ModelContext(container)
                            )
                        }
                        Task { @MainActor in
                            await EquipmentServiceReminderScheduler.resyncOwnedEquipment(
                                ownerProfileID: ownerID,
                                modelContext: ModelContext(container)
                            )
                            await DiveTripReminderScheduler.resyncOwnedTrips(
                                ownerProfileID: ownerID,
                                modelContext: ModelContext(container)
                            )
                        }
                    }
                }
                if phase == .background {
                    GoDiveCloudKitBackgroundSync.scheduleNextOpportunities()
                    GoDiveBuddyShareBackgroundUpload.scheduleProcessingIfNeeded()
                    if let ownerID = accountSession.currentProfile?.id {
                        Task {
                            await GoDiveBuddyShareBackgroundUpload.resumePendingWork(
                                ownerProfileID: ownerID,
                                modelContext: ModelContext(container)
                            )
                        }
                    }
                    Task { @MainActor in
                        DiveMediaReferenceLoader.clearSessionMediaCaches()
                    }
                }
            }
            .task {
                CrashReportingService.startAtLaunch(container: container)
                GoDiveSecurityEventJournal.configure(container: container)
                // Identity observer stays early — it only registers for CK import notifications
                // (needed if restore/sign-in races an import). Heavy kick() is deferred.
                AccountSessionCloudKitIdentityObserver.startIfNeeded(container: container)
                AppLaunchMaintenance.runInBackground(container: container)
                GoDiveCloudKitBackgroundSync.scheduleNextOpportunities()
                if accountSession.pendingICloudDiveLogReconnectOnNextLaunch,
                   accountSession.showsMainAppShell,
                   !didRunPostSignInCloudKitReconnect
                {
                    didRunPostSignInCloudKitReconnect = true
                    await runPostSignInCloudKitReconnect()
                }
                if accountSession.showsMainAppShell {
                    HomeCarouselLaunchPreload.preloadStoredPicksIfCurrent(
                        ownerProfileID: accountSession.currentProfile?.id
                    )
                    await scheduleDeferredMapWarmupFallback()
                }
            }
            .onChange(of: accountSession.isRestoringSession) { _, restoring in
                guard !restoring else { return }
                // After Gate 2 — APNs registration no longer contends with store open / restore.
                GoDiveFirebaseCloudMessaging.registerForRemoteNotificationsIfNeeded()
            }
            .onChange(of: accountSession.isHomeLaunchChromeReady) { _, isReady in
                guard isReady else { return }
                // Quiet window so first Home taps are not sharing MainActor with fetchCount / CK.
                Task { @MainActor in
                    let deferNs =
                        AppLaunchPostOverlayPresentation.postChromeCloudKitKickDeferNanoseconds
                    if deferNs > 0 {
                        try? await Task.sleep(nanoseconds: deferNs)
                    }
                    guard accountSession.isHomeLaunchChromeReady else { return }
                    GoDiveCloudKitDiveLogSyncKickstart.kick(container: container)
                }
            }
            .onChange(of: accountSession.showsMainAppShell) { _, showsMain in
                guard showsMain else { return }
                if accountSession.pendingICloudDiveLogReconnectOnNextLaunch,
                   !didRunPostSignInCloudKitReconnect
                {
                    didRunPostSignInCloudKitReconnect = true
                    Task { @MainActor in
                        await runPostSignInCloudKitReconnect()
                    }
                }
                HomeCarouselLaunchPreload.preloadStoredPicksIfCurrent(
                    ownerProfileID: accountSession.currentProfile?.id
                )
                Task {
                    await GoDiveBuddyActivityPushPreferenceSync.uploadCurrentPreference()
                    await GoDiveFirebaseCloudMessaging.registerForFriendInvitePushesIfNeeded()
                }
                Task {
                    await scheduleDeferredMapWarmupFallback()
                }
            }
            #if DEBUG
            .task {
                if MockDataSeeding.isLaunchSeedingEnabled {
                    await seedMockDataIfNeeded(container: container)
                }
            }
            #endif
    }

    @MainActor
    private func performModelContainerCloudKitReconnect() async {
        let newContainer = await AppModelContainer.reloadProductionAfterCloudKitReconnect()
        onReplaceContainer(newContainer)
        accountSession.registerActiveModelContainer(newContainer)
        AccountSessionCloudKitIdentityObserver.setActiveContainer(newContainer)
        GoDiveSecurityEventJournal.configure(container: newContainer)
        GoDiveCloudKitDiveLogSyncKickstart.kick(container: newContainer)
    }

    @MainActor
    private func runPostSignInCloudKitReconnect() async {
        await performModelContainerCloudKitReconnect()
        let context = accountSession.activeModelContainer?.mainContext ?? container.mainContext
        await accountSession.finishAfterScheduledCloudKitReconnect(modelContext: context)
    }

    @MainActor
    private func clearStalePendingCloudKitReconnectIfAlreadyEnabled() {
        guard accountSession.pendingICloudDiveLogReconnectOnNextLaunch else { return }
        guard GoDiveCloudKitDiveLogLocalStatus.readPrivateSyncState() == .enabled else { return }
        accountSession.acknowledgePendingICloudDiveLogReconnectReminder()
    }

    /// Late fallback if the user never opens Explore — prefer Explore-tab warm for first paint.
    private func scheduleDeferredMapWarmupFallback() async {
        let delay = AppLaunchPostOverlayPresentation.deferredMapWarmupDelaySeconds
        try? await Task.sleep(for: .seconds(delay))
        await MainActor.run {
            guard accountSession.showsMainAppShell else { return }
            MapKitWarmup.warmUpIfNeeded()
            #if canImport(GoogleMaps)
            GoogleMapsWarmup.warmUpIfNeeded()
            #endif
        }
    }

    #if DEBUG
    @MainActor
    private func seedMockDataIfNeeded(container: ModelContainer) async {
        let context = container.mainContext
        do {
            try MockDataSeeder.seedIfNeeded(
                context: context,
                resourceName: "dives_sample",
                resourceExtension: "json"
            )
            if let profile = accountSession.currentProfile {
                try DiveActivityOwnership.claimUnownedDives(for: profile, modelContext: context)
                try SnorkelActivityOwnership.claimUnownedSnorkels(for: profile, modelContext: context)
                try DiveBuddyOwnership.claimUnownedBuddies(for: profile, modelContext: context)
            }
        } catch {
            print("Mock data seeding failed: \(error)")
        }
    }
    #endif
}

