import SwiftUI

/// Copy for the local-first publish checkpoint banner (testable without SwiftUI).
enum ActivityPublishCheckpointBannerPresentation: Sendable {
    nonisolated static func promptTitle(activityKind: FriendSharedActivityKind) -> String {
        activityKind == .snorkel ? "This snorkel is local only" : "This dive is local only"
    }

    nonisolated static let promptSubtitle = "Share it with your buddies when you're ready."
    nonisolated static let shareButtonTitle = "Share"
    nonisolated static let keepLocalButtonTitle = "Keep local"
    nonisolated static let sharedConfirmationTitle = "Shared with buddies"

    /// How long the post-publish confirmation stays before the banner hides.
    nonisolated static let sharedConfirmationDuration: Duration = .seconds(1.6)
}

/// Strava-style publish checkpoint banner shown at the top of the activity overview panel while
/// a new activity is still a local-only draft. **Share** publishes to the buddy network (one tap,
/// current defaults); **Keep local** resolves the checkpoint without publishing.
struct ActivityPublishCheckpointBanner: View {
    let activityKind: FriendSharedActivityKind
    let onShare: () -> Void
    let onKeepLocal: () -> Void
    /// Called after the post-publish confirmation finishes — parent hides the banner.
    let onConfirmationFinished: () -> Void

    @State private var didShare = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: didShare ? "checkmark.circle.fill" : "person.2.fill")
                .font(.title3)
                .foregroundStyle(didShare ? AnyShapeStyle(.green) : AnyShapeStyle(.tint))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(
                    didShare
                        ? ActivityPublishCheckpointBannerPresentation.sharedConfirmationTitle
                        : ActivityPublishCheckpointBannerPresentation.promptTitle(activityKind: activityKind)
                )
                .font(.subheadline.weight(.semibold))
                if !didShare {
                    Text(ActivityPublishCheckpointBannerPresentation.promptSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(ActivityPublishCheckpointBannerPresentation.keepLocalButtonTitle) {
                        onKeepLocal()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 8)

            if !didShare {
                Button(ActivityPublishCheckpointBannerPresentation.shareButtonTitle) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        didShare = true
                    }
                    onShare()
                    Task {
                        try? await Task.sleep(
                            for: ActivityPublishCheckpointBannerPresentation.sharedConfirmationDuration
                        )
                        onConfirmationFinished()
                    }
                }
                .fontWeight(.semibold)
                .buttonStyle(.glassProminent)
                .tint(AppTheme.Colors.accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .appHighlightTileChrome()
        .padding(.horizontal, AppTheme.Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            didShare
                ? ActivityPublishCheckpointBannerPresentation.sharedConfirmationTitle
                : ActivityPublishCheckpointBannerPresentation.promptTitle(activityKind: activityKind)
        )
    }
}
