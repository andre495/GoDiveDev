import SwiftUI

/// Copy + chrome tokens for the local-first publish checkpoint banner (testable without SwiftUI).
enum ActivityPublishCheckpointBannerPresentation: Sendable {
    nonisolated static func promptTitle(activityKind: FriendSharedActivityKind) -> String {
        activityKind == .snorkel ? "This snorkel is local only" : "This dive is local only"
    }

    nonisolated static let promptSubtitle = "Share it with your buddies when you're ready."
    nonisolated static let shareButtonTitle = "Share"
    nonisolated static let dismissAccessibilityLabel = "Dismiss"
    nonisolated static let sharedConfirmationTitle = "Shared with buddies"

    /// Single-line compact prompt used by the seam overlay banner.
    nonisolated static func compactPromptLine(activityKind: FriendSharedActivityKind) -> String {
        "\(promptTitle(activityKind: activityKind)) — share with buddies when ready."
    }

    /// How long the post-publish confirmation stays before the banner hides.
    nonisolated static let sharedConfirmationDuration: Duration = .seconds(1.6)

    /// Gap between the banner bottom edge and the overview sheet seam.
    nonisolated static let seamGap: CGFloat = 6

    nonisolated static let cornerRadius: CGFloat = 8
    nonisolated static let verticalPadding: CGFloat = 5
    nonisolated static let horizontalPadding: CGFloat = 8
    nonisolated static let dismissHitSize: CGFloat = 18
    nonisolated static let leadingTextInset: CGFloat = 16

    /// Same ocean stops as **`AppTheme.Colors.headerTitleForegroundGradient`** (GoDive wordmark).
    static var fillGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: AppTheme.Colors.accentLight, location: 0.0),
                .init(color: AppTheme.Colors.accent, location: 0.55),
                .init(color: AppTheme.Colors.accentDeep, location: 1.0),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Compact publish-checkpoint nudge overlaid on the map just above the overview sheet seam.
/// **Share** (Liquid Glass) publishes with current defaults; small **×** (upper leading) permanently
/// dismisses. Visiting Activity Settings also dismisses. Hidden while minimized; reappears at **large**.
struct ActivityPublishCheckpointBanner: View {
    let activityKind: FriendSharedActivityKind
    let onShare: () -> Void
    let onDismiss: () -> Void
    /// Called after the post-publish confirmation finishes — parent hides the banner.
    let onConfirmationFinished: () -> Void

    @State private var didShare = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(
                didShare
                    ? ActivityPublishCheckpointBannerPresentation.sharedConfirmationTitle
                    : ActivityPublishCheckpointBannerPresentation.compactPromptLine(activityKind: activityKind)
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.leading, didShare ? 0 : ActivityPublishCheckpointBannerPresentation.leadingTextInset)

            Spacer(minLength: 4)

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
                .font(.caption.weight(.semibold))
                .controlSize(.small)
                .buttonStyle(.glass)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, ActivityPublishCheckpointBannerPresentation.horizontalPadding)
        .padding(.vertical, ActivityPublishCheckpointBannerPresentation.verticalPadding)
        .overlay(alignment: .topLeading) {
            if !didShare {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.95))
                        .frame(
                            width: ActivityPublishCheckpointBannerPresentation.dismissHitSize,
                            height: ActivityPublishCheckpointBannerPresentation.dismissHitSize
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 3)
                .padding(.leading, 4)
                .accessibilityLabel(ActivityPublishCheckpointBannerPresentation.dismissAccessibilityLabel)
            }
        }
        .background {
            RoundedRectangle(
                cornerRadius: ActivityPublishCheckpointBannerPresentation.cornerRadius,
                style: .continuous
            )
            .fill(ActivityPublishCheckpointBannerPresentation.fillGradient)
            .shadow(color: AppTheme.Colors.accent.opacity(0.28), radius: 6, y: 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            didShare
                ? ActivityPublishCheckpointBannerPresentation.sharedConfirmationTitle
                : ActivityPublishCheckpointBannerPresentation.promptTitle(activityKind: activityKind)
        )
    }
}
