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
    init() {
        guard GoDiveUITestConfiguration.isActive else { return }
        UIView.setAnimationsEnabled(false)
    }
    /// When **`XCUIApplication`** passes **`-GoDiveUITest`**, skip the seeding overlay so the main UI is visible immediately (XCTest waits for an AX-ready window; hiding **`ContentView`** behind **`opacity(0)`** can time out).
    #if DEBUG
    @State private var isSeedingData: Bool = {
        !GoDiveUITestConfiguration.isActive
    }()
    #else
    @State private var isSeedingData = false
    #endif

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
            ContentView()
                .opacity(isSeedingData ? 0 : 1)

            if isSeedingData {
                SeedingLaunchOverlay()
                    .transition(.opacity)
            }
        }
        .modelContainer(AppModelContainer.production)
        .task {
            await MainActor.run {
                try? DiveActivityDiveNumbering.backfillMissingDiveNumbers(
                    modelContext: AppModelContainer.production.mainContext
                )
            }
            #if DEBUG
            await seedMockDataIfNeeded()
            #endif
            await MainActor.run {
                try? DiveActivityDiveNumbering.backfillMissingDiveNumbers(
                    modelContext: AppModelContainer.production.mainContext
                )
            }
        }
    }

    #if DEBUG
    /// Inserts or syncs dives from bundled JSON. **Debug builds only** — Release has no mock seeding.
    @MainActor
    private func seedMockDataIfNeeded() async {
        defer {
            withAnimation(.easeOut(duration: 0.2)) {
                isSeedingData = false
            }
        }

        do {
            // Bundled mock fixture file (swap name for another JSON with the same DTO shape). Omit entirely once live data loads the store.
            try MockDataSeeder.seedIfNeeded(
                context: AppModelContainer.production.mainContext,
                resourceName: "dives_sample",
                resourceExtension: "json"
            )
        } catch {
            print("Mock data seeding failed: \(error)")
        }
    }
    #endif
}
