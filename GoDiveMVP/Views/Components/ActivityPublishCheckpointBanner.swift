import SwiftUI

/// Copy + chrome tokens for the local-first publish checkpoint banner (testable without SwiftUI).
enum ActivityPublishCheckpointBannerPresentation: Sendable {
    nonisolated static let promptTitle = "Share with Buddies?"

    /// Trailing phrase before the inline **⋯** Activity Settings affordance.
    nonisolated static let promptSubtitlePrefix = "You can change the sharing setting anytime from"

    nonisolated static let menuEllipsisSystemImage = "ellipsis"
    nonisolated static let shareButtonTitle = "Share"
    nonisolated static let dismissAccessibilityLabel = "Dismiss"
    nonisolated static let sharedConfirmationTitle = "Shared with buddies"

    /// Accessibility / VoiceOver label for the prompt (title + subtitle + ⋯ hint).
    nonisolated static var promptAccessibilityLabel: String {
        "\(promptTitle). \(promptSubtitlePrefix) the menu button."
    }

    /// How long the post-publish confirmation stays before the banner hides.
    nonisolated static let sharedConfirmationDuration: Duration = .seconds(1.6)

    /// Gap between the banner bottom edge and the overview sheet seam.
    nonisolated static let seamGap: CGFloat = 6

    nonisolated static let cornerRadius: CGFloat = 10
    /// ~30% taller than the prior single-line compact chrome (`5` → `7`).
    nonisolated static let verticalPadding: CGFloat = 7
    nonisolated static let horizontalPadding: CGFloat = 8
    nonisolated static let dismissHitSize: CGFloat = 18
    nonisolated static let leadingTextInset: CGFloat = 16
    nonisolated static let titleSubtitleSpacing: CGFloat = 2

    /// Exit motion after **×** (down into the sheet seam) vs after **Share** (up off the map).
    enum ExitDirection: Sendable, Equatable {
        case down
        case up
    }

    nonisolated static let dismissAnimationDuration: TimeInterval = 0.22
    nonisolated static let shareExitAnimationDuration: TimeInterval = 0.28

    /// Edge the banner exits toward — **×** → bottom (sheet), **Share** → top (off map).
    nonisolated static func removalEdge(for exitDirection: ExitDirection) -> Edge {
        switch exitDirection {
        case .up: .top
        case .down: .bottom
        }
    }

    /// Enters from the sheet seam; removal direction is chosen by the parent.
    static func transition(exitDirection: ExitDirection) -> AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .bottom)),
            removal: .opacity.combined(with: .move(edge: removalEdge(for: exitDirection)))
        )
    }

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
    let onShare: () -> Void
    let onDismiss: () -> Void
    /// Called after the post-publish confirmation finishes — parent hides the banner.
    let onConfirmationFinished: () -> Void

    @State private var didShare = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if didShare {
                Text(ActivityPublishCheckpointBannerPresentation.sharedConfirmationTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            } else {
                promptCopy
                    .padding(.leading, ActivityPublishCheckpointBannerPresentation.leadingTextInset)
            }

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
                : ActivityPublishCheckpointBannerPresentation.promptAccessibilityLabel
        )
    }

    private var promptCopy: some View {
        VStack(alignment: .leading, spacing: ActivityPublishCheckpointBannerPresentation.titleSubtitleSpacing) {
            Text(ActivityPublishCheckpointBannerPresentation.promptTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text(
                "\(ActivityPublishCheckpointBannerPresentation.promptSubtitlePrefix) \(Image(systemName: ActivityPublishCheckpointBannerPresentation.menuEllipsisSystemImage))"
            )
            .font(.caption2.weight(.medium))
            .foregroundStyle(.white.opacity(0.92))
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
