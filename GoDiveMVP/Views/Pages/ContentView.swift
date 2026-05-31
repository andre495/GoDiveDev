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

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: RootTab.home) {
                LogOverviewView(ownerProfileID: accountSession.currentProfile?.id)
                    .id(accountSession.currentProfile?.id)
            }

            Tab("Logbook", systemImage: "book.closed", value: RootTab.logbook) {
                LogbookView(ownerProfileID: accountSession.currentProfile?.id)
                    .id(accountSession.currentProfile?.id)
            }

            Tab("Field Guide", systemImage: "leaf", value: RootTab.fieldGuide) {
                FieldGuideView()
            }

            Tab("Explore", systemImage: "map", value: RootTab.explore) {
                ExploreView()
            }
        }
        .accessibilityIdentifier("GoDive.RootTabs")
        .tint(AppTheme.Colors.tabSelected)
        .goDiveRootTabBarChrome()
        .modifier(TabBarMinimizeWhenNotUITesting())
        .environment(\.diveDisplayUnitSystem, useImperialDisplayUnits ? .imperial : .metric)
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
