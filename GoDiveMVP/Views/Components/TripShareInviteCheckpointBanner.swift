import SwiftUI

/// Accept / Decline chrome for a pending trip-share invite on trip detail.
struct TripShareInviteCheckpointBanner: View {
    let sharerDisplayName: String?
    let onAccept: () -> Void
    let onDecline: () -> Void
    var isBusy: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(DiveTripShareInvitePresentation.pendingBannerTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text(DiveTripShareInvitePresentation.pendingBannerMessage(sharerDisplayName: sharerDisplayName))
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: AppTheme.Spacing.sm) {
                Button(DiveTripShareInvitePresentation.declineButtonTitle, role: .destructive) {
                    onDecline()
                }
                .buttonStyle(.bordered)
                .disabled(isBusy)

                Button(DiveTripShareInvitePresentation.acceptButtonTitle) {
                    onAccept()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.Colors.accent)
                .disabled(isBusy)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(AppTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        )
        .accessibilityIdentifier("TripDetail.ShareInvite.Banner")
    }
}
