import CoreGraphics
import Foundation

/// Panel scroll offset preservation when nested **`NavigationLink`** pushes cover the dive overview.
enum DiveActivityOverviewScrollRestoration: Sendable {

    /// Ignore near-zero scroll reports while tearing down the inset (avoids wiping saved offset).
    nonisolated static func shouldPersistScrollOffsetBinding(
        proposedOffset: CGFloat,
        acceptsPersistence: Bool
    ) -> Bool {
        acceptsPersistence
    }

    /// Scroll teardown often reports **0** in one frame; do not wipe a deep saved offset.
    nonisolated static func shouldIgnoreSuddenScrollResetToTop(
        proposedOffset: CGFloat,
        persistedOffset: CGFloat,
        lastReportedOffset: CGFloat
    ) -> Bool {
        guard proposedOffset < 4, persistedOffset > 32 else { return false }
        let prior = max(persistedOffset, lastReportedOffset)
        return prior > 32 && abs(proposedOffset - lastReportedOffset) > 24
    }

    /// Offset to keep when suspending persistence (binding + last geometry sample).
    nonisolated static func preservedScrollOffset(
        binding: CGFloat,
        lastReportedOffset: CGFloat
    ) -> CGFloat {
        max(binding, lastReportedOffset)
    }

    /// Resting offset used to rebuild the top inset spacer on return.
    nonisolated static func effectiveScrollOffsetForRestoration(
        persisted: CGFloat,
        fallback: CGFloat
    ) -> CGFloat {
        let merged = max(persisted, fallback)
        return merged > 4 ? merged : 0
    }

    /// Inset spacer restoration runs only when popping back from nested navigation
    /// (**`fallbackScrollOffsetY`** from the UI state store while the live binding still reads ~0).
    /// Live scroll offsets must not inject a spacer — that breaks **`ScrollView`** once content exceeds the panel (e.g. Weather).
    nonisolated static func shouldApplyScrollRestorationInset(
        fallback: CGFloat,
        persisted: CGFloat
    ) -> Bool {
        guard fallback > 4 else { return false }
        guard persisted < 4 else { return false }
        return effectiveScrollOffsetForRestoration(persisted: persisted, fallback: fallback) > 4
    }
}
