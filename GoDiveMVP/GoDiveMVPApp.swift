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
    @State private var accountSession = AccountSession.shared

    init() {
        guard GoDiveUITestConfiguration.isActive else { return }
        UIView.setAnimationsEnabled(false)
    }

    var body: some Scene {
        WindowGroup {
            if GoDiveUITestConfiguration.isActive {
                GoDiveUITestRootView()
            } else {
                productionRoot
            }
        }
    }

    private var productionRoot: some View {
        ZStack {
            if MapKitWarmup.shouldWarmUp {
                MapKitWarmupView()
                    .allowsHitTesting(false)
            }

            AppSessionRootView()
        }
        .environment(accountSession)
        .modelContainer(AppModelContainer.production)
        .task {
            await MainActor.run {
                let context = AppModelContainer.production.mainContext
                try? DiveActivityDiveNumbering.backfillMissingDiveNumbers(modelContext: context)
                try? MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)
            }
            #if DEBUG
            if MockDataSeeding.isLaunchSeedingEnabled {
                await seedMockDataIfNeeded()
            }
            #endif
            await MainActor.run {
                try? DiveActivityDiveNumbering.backfillMissingDiveNumbers(
                    modelContext: AppModelContainer.production.mainContext
                )
            }
        }
    }

    #if DEBUG
    /// Inserts or syncs dives from bundled JSON when **`MockDataSeeding.isLaunchSeedingEnabled`** is **`true`**.
    @MainActor
    private func seedMockDataIfNeeded() async {
        let context = AppModelContainer.production.mainContext
        do {
            try MockDataSeeder.seedIfNeeded(
                context: context,
                resourceName: "dives_sample",
                resourceExtension: "json"
            )
            if let profile = accountSession.currentProfile {
                try DiveActivityOwnership.claimUnownedDives(for: profile, modelContext: context)
            }
        } catch {
            print("Mock data seeding failed: \(error)")
        }
    }
    #endif
}
