import SwiftUI

/// Shared media/map hero rules for pushed detail pages (profile, buddy, friend, tag, trip, species, site).
enum PushedDetailHeroModePresentation: Sendable {

    /// Show the camera/map toggle only when both associated media and map content exist.
    nonisolated static func showsModeToggle(
        hasAssociatedMedia: Bool,
        hasMapContent: Bool
    ) -> Bool {
        hasAssociatedMedia && hasMapContent
    }

    /// Map-only when there is no media; otherwise default to media.
    nonisolated static func resolvedMode(
        hasAssociatedMedia: Bool,
        hasMapContent: Bool
    ) -> PushedDetailHeroHeaderView.Mode {
        if hasAssociatedMedia { return .media }
        if hasMapContent { return .map }
        return .media
    }

    nonisolated static func enforceModeWhenToggleHidden(
        _ mode: PushedDetailHeroHeaderView.Mode,
        hasAssociatedMedia: Bool,
        hasMapContent: Bool
    ) -> PushedDetailHeroHeaderView.Mode {
        guard showsModeToggle(hasAssociatedMedia: hasAssociatedMedia, hasMapContent: hasMapContent) else {
            return resolvedMode(
                hasAssociatedMedia: hasAssociatedMedia,
                hasMapContent: hasMapContent
            )
        }
        return mode
    }

    nonisolated static func heroModeBinding(
        hasAssociatedMedia: Bool,
        hasMapContent: Bool,
        mode: Binding<PushedDetailHeroHeaderView.Mode>
    ) -> Binding<PushedDetailHeroHeaderView.Mode> {
        guard showsModeToggle(hasAssociatedMedia: hasAssociatedMedia, hasMapContent: hasMapContent) else {
            return .constant(
                resolvedMode(
                    hasAssociatedMedia: hasAssociatedMedia,
                    hasMapContent: hasMapContent
                )
            )
        }
        return mode
    }

    /// When the user can choose media, fall back from an empty map after pins load — not during deferred map mount.
    nonisolated static func shouldFallBackFromMapToMedia(
        mapPinCount: Int,
        currentMode: PushedDetailHeroHeaderView.Mode,
        isMapContentReady: Bool,
        hasAssociatedMedia: Bool
    ) -> Bool {
        guard hasAssociatedMedia else { return false }
        guard isMapContentReady else { return false }
        guard currentMode == .map else { return false }
        return mapPinCount == 0
    }
}
