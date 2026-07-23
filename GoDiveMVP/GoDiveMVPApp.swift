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
        // Backup if App Delegate has not run yet; primary configure is in GoDiveGoogleMapsAppDelegate.
        GoDiveFirebaseBootstrap.configureIfNeeded()
        AppUserSettings.registerDefaultValues()
        guard GoDiveUITestConfiguration.isActive else {
            AppModelContainer.beginLoadingProductionIfNeeded()
            return
        }
        UIView.setAnimationsEnabled(false)
    }

    var body: some Scene {
        WindowGroup {
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
                AppLaunchOverlay(showsProgressIndicator: true)
                    .task { productionContainer = await AppModelContainer.loadProduction() }
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
                GoDiveCloudKitDiveLogSyncKickstart.kick(container: container)
                clearStalePendingCloudKitReconnectIfAlreadyEnabled()
                isSessionRestoreAllowed = true
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
                    Task { await GoDiveFirebaseCloudMessaging.registerForFriendInvitePushesIfNeeded() }
                }
                if phase == .background {
                    GoDiveCloudKitBackgroundSync.scheduleNextOpportunities()
                    Task { @MainActor in
                        DiveMediaReferenceLoader.clearSessionMediaCaches()
                    }
                }
            }
            .task {
                CrashReportingService.startAtLaunch(container: container)
                GoDiveSecurityEventJournal.configure(container: container)
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
                }
                await scheduleDeferredMapWarmup()
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
                Task { await GoDiveFirebaseCloudMessaging.registerForFriendInvitePushesIfNeeded() }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(600))
                    #if canImport(GoogleMaps)
                    GoogleMapsWarmup.warmUpIfNeeded()
                    #endif
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

    private func scheduleDeferredMapWarmup() async {
        try? await Task.sleep(for: .milliseconds(400))
        await MainActor.run {
            MapKitWarmup.warmUpIfNeeded()
            #if canImport(GoogleMaps)
            if accountSession.showsMainAppShell {
                GoogleMapsWarmup.warmUpIfNeeded()
            }
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

