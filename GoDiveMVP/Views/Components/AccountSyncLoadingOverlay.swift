import SwiftUI

/// Full-screen loading overlay shown while syncing a returning account.
/// Matches the launch screen style with an added progress message.
struct AccountSyncLoadingOverlay: View {
    let progressMessage: String
    var onRetry: (() -> Void)? = nil
    var onContinue: (() -> Void)? = nil
    var failureReason: AccountSyncState.FailureReason? = nil

    var body: some View {
        GeometryReader { geo in
            let safeMidY = AppLaunchLayout.safeAreaMidY(
                viewHeight: geo.size.height,
                safeAreaTop: geo.safeAreaInsets.top,
                safeAreaBottom: geo.safeAreaInsets.bottom
            )
            let logoCenterY = AppLaunchLayout.logoCenterY(safeAreaMidY: safeMidY)
            let titleCenterY = AppLaunchLayout.titleCenterY(logoCenterY: logoCenterY)
            let centerX = geo.size.width / 2

            ZStack {
                launchScreenBackground
                    .ignoresSafeArea()

                GoDiveLogoPinPresentation.image
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: AppLaunchLayout.logoSize,
                        height: AppLaunchLayout.logoSize
                    )
                    .position(x: centerX, y: logoCenterY)
                    .accessibilityHidden(true)

                Text("GoDive")
                    .font(AppTheme.Typography.headerBrandTitle.weight(.bold))
                    .foregroundStyle(launchTitleColor)
                    .position(x: centerX, y: titleCenterY)

                if let failureReason {
                    failureContent(reason: failureReason)
                        .position(
                            x: centerX,
                            y: AppLaunchLayout.progressCenterY(titleCenterY: titleCenterY) + 40
                        )
                } else {
                    loadingContent
                        .position(
                            x: centerX,
                            y: AppLaunchLayout.progressCenterY(titleCenterY: titleCenterY)
                        )
                }
            }
        }
        .accessibilityIdentifier("AccountSync.LoadingOverlay")
    }

    private var loadingContent: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            GoDiveRotateLoadingIndicator(
                size: .large,
                tint: launchTitleColor,
                accessibilityLabel: "Syncing account"
            )

            Text(progressMessage)
                .font(.body)
                .foregroundStyle(launchTitleColor.opacity(0.85))
                .multilineTextAlignment(.center)
                .accessibilityLabel(progressMessage)
                .accessibilityIdentifier("AccountSync.ProgressMessage")
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func failureContent(reason: AccountSyncState.FailureReason) -> some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            VStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: failureSystemImage(for: reason))
                    .font(.largeTitle)
                    .foregroundStyle(launchTitleColor.opacity(0.7))
                    .accessibilityHidden(true)

                Text(failureTitle(for: reason))
                    .font(.headline)
                    .foregroundStyle(launchTitleColor)

                Text(failureMessage(for: reason))
                    .font(.subheadline)
                    .foregroundStyle(launchTitleColor.opacity(0.85))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: AppTheme.Spacing.md) {
                if let onRetry {
                    Button(action: onRetry) {
                        Text(AccountSyncLoadingPresentation.retryButtonTitle)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(launchTitleColor)
                            .padding(.horizontal, AppTheme.Spacing.lg)
                            .padding(.vertical, AppTheme.Spacing.sm)
                            .background(
                                Capsule()
                                    .fill(launchTitleColor.opacity(0.2))
                            )
                    }
                    .accessibilityIdentifier("AccountSync.RetryButton")
                }

                if let onContinue {
                    Button(action: onContinue) {
                        Text(AccountSyncLoadingPresentation.continueButtonTitle)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(launchScreenBackground)
                            .padding(.horizontal, AppTheme.Spacing.lg)
                            .padding(.vertical, AppTheme.Spacing.sm)
                            .background(
                                Capsule()
                                    .fill(launchTitleColor)
                            )
                    }
                    .accessibilityIdentifier("AccountSync.ContinueButton")
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .accessibilityElement(children: .contain)
    }

    private func failureSystemImage(for reason: AccountSyncState.FailureReason) -> String {
        switch reason {
        case .offline:
            "wifi.slash"
        case .iCloudUnavailable:
            "icloud.slash"
        case .unknown:
            "exclamationmark.triangle"
        }
    }

    private func failureTitle(for reason: AccountSyncState.FailureReason) -> String {
        switch reason {
        case .offline:
            AccountSyncLoadingPresentation.offlineTitle
        case .iCloudUnavailable:
            AccountSyncLoadingPresentation.iCloudUnavailableTitle
        case .unknown:
            "Sync failed"
        }
    }

    private func failureMessage(for reason: AccountSyncState.FailureReason) -> String {
        switch reason {
        case .offline:
            AccountSyncLoadingPresentation.offlineMessage
        case .iCloudUnavailable:
            AccountSyncLoadingPresentation.iCloudUnavailableMessage
        case .unknown(let message):
            message.isEmpty ? "Please try again." : message
        }
    }

    private var launchScreenBackground: Color {
        Color(
            red: AppLaunchLayout.fixedBackgroundRed,
            green: AppLaunchLayout.fixedBackgroundGreen,
            blue: AppLaunchLayout.fixedBackgroundBlue
        )
    }

    private var launchTitleColor: Color {
        Color(
            red: AppLaunchLayout.fixedTitleRed,
            green: AppLaunchLayout.fixedTitleGreen,
            blue: AppLaunchLayout.fixedTitleBlue
        )
    }
}

#Preview("Loading") {
    AccountSyncLoadingOverlay(progressMessage: "Restoring your dives…")
}

#Preview("Offline") {
    AccountSyncLoadingOverlay(
        progressMessage: "",
        onRetry: {},
        onContinue: {},
        failureReason: .offline
    )
}
