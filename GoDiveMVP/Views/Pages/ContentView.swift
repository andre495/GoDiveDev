//
//  ContentView.swift
//  GoDiveMVP
//
//  Created by André Dugas on 4/1/26.
//

import SwiftUI

struct ContentView: View {
    @AppStorage(AppUserSettings.useImperialDisplayUnitsKey) private var useImperialDisplayUnits = false

    var body: some View {
        TabView {
            LogOverviewView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            LogbookView()
                .tabItem {
                    Label("Logbook", systemImage: "book.closed")
                }

            FieldGuideView()
                .tabItem {
                    Label("Field Guide", systemImage: "leaf")
                }

            ExploreView()
                .tabItem {
                    Label("Explore", systemImage: "map")
                }
        }
        .accessibilityIdentifier("GoDive.RootTabs")
        .tint(AppTheme.Colors.tabSelected)
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
