//
//  ContentView.swift
//  GoDiveMVP
//
//  Created by André Dugas on 4/1/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(AccountSession.self) private var accountSession
    @AppStorage(AppUserSettings.useImperialDisplayUnitsKey) private var useImperialDisplayUnits = true

    /// Selection binding is required for iOS 18+ tab re-tap scroll-to-top / pop-to-root (see Apple Developer Forums thread 773497).
    @State private var selectedTab: RootTab = .home
    @State private var searchQuery = ""
    @State private var searchContextTokens: [GlobalSearchPresentation.ContextToken] = []
    @State private var pendingLogbookRoute: LogbookRoute?

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: RootTab.home) {
                LogOverviewView(ownerProfileID: accountSession.currentProfile?.id)
                    .id(accountSession.currentProfile?.id)
            }

            Tab("Logbook", systemImage: "book.closed", value: RootTab.logbook) {
                LogbookView(
                    ownerProfileID: accountSession.currentProfile?.id,
                    pendingRoute: $pendingLogbookRoute
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
        .accessibilityIdentifier("GoDive.RootTabs")
        .tint(AppTheme.Colors.tabSelected)
        .goDiveRootTabBarChrome()
        .modifier(TabBarMinimizeWhenNotUITesting())
        .environment(\.diveDisplayUnitSystem, useImperialDisplayUnits ? .imperial : .metric)
        .environment(\.openDiveImport) {
            selectedTab = .logbook
            pendingLogbookRoute = .addActivity
        }
        .onAppear {
            CrashBreadcrumbTrail.noteRootTab(selectedTab)
        }
        .onChange(of: selectedTab) { _, tab in
            CrashBreadcrumbTrail.noteRootTab(tab)
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
