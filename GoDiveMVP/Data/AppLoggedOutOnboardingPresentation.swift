import Foundation

/// Pre–Sign in with Apple onboarding — welcome activity picker + conditional feature carousel.
enum AppLoggedOutOnboardingPresentation: Sendable {
    nonisolated static let completedUserDefaultsKey = "goDiveLoggedOutOnboardingCompleted" // legacy; no longer gates onboarding

    nonisolated static let rootAccessibilityIdentifier = "LoggedOutOnboarding.Root"
    nonisolated static let welcomeAccessibilityIdentifier = "LoggedOutOnboarding.Welcome"
    nonisolated static let continueButtonTitle = "Continue"
    nonisolated static let getStartedButtonTitle = "Get started"
    nonisolated static let skipButtonTitle = "Skip"
    nonisolated static let welcomeTitle = "Welcome to GoDive"
    nonisolated static let welcomeSubtitle = "What do you do in the water?"
    nonisolated static let welcomeContinueTitle = "Show me around"
    nonisolated static let existingAccountSignInTitle = "Already have an account? Sign in"
    nonisolated static let signUpTitle = "Create your GoDive log"
    nonisolated static let signUpSubtitle =
        "Sign in with Apple to save your dives, buddies, and sightings on this device."

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

    nonisolated static func continueButtonTitle(
        featurePageIndex: Int,
        featurePageCount: Int
    ) -> String {
        let lastFeatureIndex = max(featurePageCount - 1, 0)
        return featurePageIndex >= lastFeatureIndex
            ? getStartedButtonTitle
            : continueButtonTitle
    }

    nonisolated static func isSignUpPhase(featurePageIndex: Int, featurePageCount: Int) -> Bool {
        featurePageIndex >= featurePageCount
    }
}

/// Feature-carousel slide layout — copy + bottom chrome spacing for two-line titles.
enum LoggedOutOnboardingFeatureSlidePresentation: Sendable {
    nonisolated static let titleLineLimit = 2
    nonisolated static let demoMaxHeight: CGFloat = 418
    nonisolated static let copyTopSpacing: CGFloat = AppTheme.Spacing.md
    nonisolated static let copyBottomSpacing: CGFloat = AppTheme.Spacing.sm
    /// Top padding above the page indicator inside bottom chrome.
    nonisolated static let bottomChromeTopPadding: CGFloat = 0
    /// Spacing between page dots and Continue / Get started.
    nonisolated static let bottomChromeStackSpacing: CGFloat = AppTheme.Spacing.sm
    /// Distance from the physical screen bottom (chrome ignores the bottom safe area).
    nonisolated static let bottomChromeBottomPadding: CGFloat = 14

    /// Strong pulse on the last-slide **Get started** control so it reads as the next action.
    nonisolated static let getStartedCalloutPeakScale: CGFloat = 1.2
    nonisolated static let getStartedCalloutMinOpacity: Double = 0.55
    nonisolated static let getStartedCalloutCycleSeconds: Double = 0.7
    /// How many scale-up / scale-down pulses before the label settles to static text.
    nonisolated static let getStartedCalloutPulseCount = 2
}
