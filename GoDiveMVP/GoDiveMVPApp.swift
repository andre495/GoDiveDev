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
        AppUserSettings.registerDefaultValues()
        guard GoDiveUITestConfiguration.isActive else { return }
        UIView.setAnimationsEnabled(false)
    }

    var body: some Scene {
        WindowGroup {
            if GoDiveUITestConfiguration.isActive {
                GoDiveUITestRootView()
            } else if let productionContainer {
                productionRoot(container: productionContainer)
            } else {
                AppLaunchOverlay(showsProgressIndicator: true)
                    .task { productionContainer = await AppModelContainer.loadProduction() }
            }
        }
    }

    private func productionRoot(container: ModelContainer) -> some View {
        ProductionAppRoot(container: container, accountSession: accountSession)
    }
}

/// Production shell — scene lifecycle clears Home media warm caches when the app backgrounds.
private struct ProductionAppRoot: View {
    let container: ModelContainer
    @Bindable var accountSession: AccountSession
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        AppSessionRootView()
            .environment(accountSession)
            .modelContainer(container)
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    Task { @MainActor in
                        DiveMediaReferenceLoader.clearSessionMediaCaches()
                    }
                }
            }
            .task {
                AppLaunchMaintenance.runInBackground(container: container)
                await scheduleDeferredMapWarmup()
            }
            #if DEBUG
            .task {
                if MockDataSeeding.isLaunchSeedingEnabled {
                    await seedMockDataIfNeeded(container: container)
                }
            }
            #endif
    }

    private func scheduleDeferredMapWarmup() async {
        try? await Task.sleep(for: .milliseconds(400))
        await MainActor.run {
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
                try DiveBuddyOwnership.claimUnownedBuddies(for: profile, modelContext: context)
            }
        } catch {
            print("Mock data seeding failed: \(error)")
        }
    }
    #endif
}

