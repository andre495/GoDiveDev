import Foundation

/// Pre–Sign in with Apple onboarding — welcome activity picker + conditional feature carousel.
enum AppLoggedOutOnboardingPresentation: Sendable {
    nonisolated static let completedUserDefaultsKey = "goDiveLoggedOutOnboardingCompleted" // legacy; no longer gates onboarding

    nonisolated static let rootAccessibilityIdentifier = "LoggedOutOnboarding.Root"
    nonisolated static let welcomeAccessibilityIdentifier = "LoggedOutOnboarding.Welcome"
    nonisolated static let continueButtonTitle = "Continue"
    nonisolated static let skipButtonTitle = "Skip"
    nonisolated static let welcomeTitle = "Welcome to GoDive"
    nonisolated static let welcomeSubtitle = "What do you do in the water?"
    nonisolated static let welcomeContinueTitle = "Get Started"
    nonisolated static let existingAccountSignInTitle = "Already have an account? Sign in"

    enum FeatureKind: String, CaseIterable, Sendable {
        case logEveryDive
        case trackSnorkeling
        case exploreSites
        case shareWithFriends
        case monitorEquipment
        case marineSpecies
    }

    struct FeaturePage: Identifiable, Hashable, Sendable {
        let kind: FeatureKind
        let systemImage: String
        let title: String
        let body: String
        let accentSymbolName: String?

        var id: String { kind.rawValue }

        nonisolated var accessibilityIdentifier: String {
            "LoggedOutOnboarding.Page.\(kind.rawValue)"
        }
    }

    nonisolated static func featurePages(for selection: UserOnboardingActivitySelection) -> [FeaturePage] {
        FeatureKind.allCases.compactMap { kind in
            guard shouldIncludeFeature(kind, selection: selection) else { return nil }
            return catalogPage(for: kind)
        }
    }

    nonisolated static func shouldIncludeFeature(
        _ kind: FeatureKind,
        selection: UserOnboardingActivitySelection
    ) -> Bool {
        switch kind {
        case .logEveryDive:
            return selection.doesScubaDiving || selection.doesFreeDiving
        case .trackSnorkeling:
            return selection.doesSnorkeling
        case .exploreSites, .shareWithFriends, .monitorEquipment:
            return true
        case .marineSpecies:
            return selection.doesScubaDiving || selection.doesSnorkeling
        }
    }

    nonisolated private static func catalogPage(for kind: FeatureKind) -> FeaturePage {
        switch kind {
        case .logEveryDive:
            FeaturePage(
                kind: kind,
                systemImage: "water.waves",
                title: "Log every dive",
                body: "Import Garmin and UDDF files, review depth and tank profiles, and keep a searchable logbook on your phone.",
                accentSymbolName: "chart.xyaxis.line"
            )
        case .trackSnorkeling:
            FeaturePage(
                kind: kind,
                systemImage: "water.waves.and.arrow.down",
                title: "Track your snorkeling activities",
                body: "Record surface swims, attach photos from your library, and build a searchable snorkel log.",
                accentSymbolName: "camera.fill"
            )
        case .exploreSites:
            FeaturePage(
                kind: kind,
                systemImage: "globe.americas.fill",
                title: "Explore sites across the world",
                body: "Browse thousands of dive sites on the map, plan trips, and open rich site detail pages.",
                accentSymbolName: "mappin.and.ellipse"
            )
        case .shareWithFriends:
            FeaturePage(
                kind: kind,
                systemImage: "person.2.fill",
                title: "Share experiences with your friends",
                body: "Tag dive buddies, plan trips together, and relive shared adventures from your logbook.",
                accentSymbolName: "airplane"
            )
        case .monitorEquipment:
            FeaturePage(
                kind: kind,
                systemImage: "archivebox.fill",
                title: "Monitor your equipment",
                body: "Track cameras, masks, snorkels, regulators, and service dates in your equipment locker.",
                accentSymbolName: "camera.metering.center.weighted"
            )
        case .marineSpecies:
            FeaturePage(
                kind: kind,
                systemImage: "fish.fill",
                title: "Learn from thousands of marine species",
                body: "Browse the Field Guide, tag sightings on your photos, and discover what lives at each site.",
                accentSymbolName: "leaf.fill"
            )
        }
    }

    nonisolated static func shouldPresentOnboarding(
        isUITest: Bool = GoDiveUITestConfiguration.isActive
    ) -> Bool {
        !isUITest
    }

    nonisolated static func showsContinueButton(
        featurePageIndex: Int,
        featurePageCount: Int
    ) -> Bool {
        guard featurePageCount > 0 else { return false }
        return featurePageIndex < featurePageCount - 1
    }

    nonisolated static func showsSignInWithAppleOnLastFeatureSlide(
        featurePageIndex: Int,
        featurePageCount: Int
    ) -> Bool {
        guard featurePageCount > 0 else { return false }
        return featurePageIndex >= featurePageCount - 1
    }

    /// Skip jumps to the dedicated sign-in screen — hide it on the last feature slide.
    nonisolated static func showsSkipButton(
        featurePageIndex: Int,
        featurePageCount: Int
    ) -> Bool {
        showsContinueButton(featurePageIndex: featurePageIndex, featurePageCount: featurePageCount)
    }

    /// Feature carousel always shows **Back** — first slide returns to the welcome interests picker.
    nonisolated static func showsFeatureBackButton(
        featurePageCount: Int
    ) -> Bool {
        featurePageCount > 0
    }

    /// When **true**, **Back** on the feature carousel returns to welcome; otherwise previous slide.
    nonisolated static func featureBackReturnsToWelcome(featurePageIndex: Int) -> Bool {
        featurePageIndex <= 0
    }
}

/// Feature-carousel slide layout — copy + bottom chrome spacing for two-line titles.
enum LoggedOutOnboardingFeatureSlidePresentation: Sendable {
    nonisolated static let titleLineLimit = 2
    nonisolated static let demoMaxHeight: CGFloat = 418
    nonisolated static let copyTopSpacing: CGFloat = AppTheme.Spacing.md
    nonisolated static let copyBottomSpacing: CGFloat = AppTheme.Spacing.sm
    /// Top padding above the bottom chrome row (Continue / Sign in with Apple).
    nonisolated static let bottomChromeTopPadding: CGFloat = 0
    /// Spacing between Continue / Sign in with Apple and the page indicator below.
    nonisolated static let bottomChromeStackSpacing: CGFloat = AppTheme.Spacing.sm
    /// Distance from the physical screen bottom to the page indicator (chrome ignores the bottom safe area).
    nonisolated static let bottomChromeBottomPadding: CGFloat = 14
}
