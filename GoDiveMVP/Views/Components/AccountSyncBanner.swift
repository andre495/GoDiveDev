import SwiftUI

/// Non-blocking banner shown at top of Home when sync times out.
/// Disappears automatically when data lands.
struct AccountSyncBanner: View {
    let message: String
    var isComplete: Bool = false
    var onDismiss: (() -> Void)? = nil

    @State private var isVisible = true

    var body: some View {
        if isVisible {
            HStack(spacing: AppTheme.Spacing.sm) {
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.Colors.accent)
                        .accessibilityHidden(true)
                } else {
                    GoDiveRotateLoadingIndicator(
                        size: .compact,
                        tint: AppTheme.Colors.secondaryText,
                        accessibilityLabel: "Syncing"
                    )
                }

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.primaryText)

                Spacer()

                if isComplete, let onDismiss {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isVisible = false
                        }
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                    .accessibilityLabel("Dismiss")
                    .accessibilityIdentifier("AccountSync.DismissBanner")
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.surfaceElevated)
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            )
            .padding(.horizontal, AppTheme.Spacing.md)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("AccountSync.Banner")
            .onChange(of: isComplete) { _, nowComplete in
                if nowComplete {
                    autoDismissAfterDelay()
                }
            }
        }
    }

    private func autoDismissAfterDelay() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard isComplete else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                isVisible = false
            }
            onDismiss?()
        }
    }
}

#Preview("Still Syncing") {
    VStack {
        AccountSyncBanner(message: AccountSyncLoadingPresentation.stillSyncingBannerMessage)
        Spacer()
    }
    .background(AppTheme.Colors.screenBackgroundGradient)
}

#Preview("Sync Complete") {
    VStack {
        AccountSyncBanner(
            message: AccountSyncLoadingPresentation.syncCompleteBannerMessage,
            isComplete: true,
            onDismiss: {}
        )
        Spacer()
    }
    .background(AppTheme.Colors.screenBackgroundGradient)
}
