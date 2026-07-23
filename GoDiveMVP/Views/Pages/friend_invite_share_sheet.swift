import SwiftUI
import UIKit

/// QR + share / copy for a friend invite link.
struct FriendInviteShareSheet: View {
    let inviteURL: URL
    let onRevoke: () -> Void

    @State private var didCopy = false
    @State private var qrImage: UIImage?

    private var qrSize: CGFloat { FriendInviteShareSheetPresentation.qrDisplaySize }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                Text(GoDiveFriendsPresentation.inviteSheetTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)

                Group {
                    if let qrImage {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: qrSize, height: qrSize)
                            .accessibilityLabel("Friend invite QR code")
                    } else {
                        ProgressView()
                            .frame(width: qrSize, height: qrSize)
                            .accessibilityLabel("Generating friend invite QR code")
                    }
                }
                .frame(maxWidth: .infinity)

                Text(verbatim: inviteURL.absoluteString)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity)

                HStack(spacing: AppTheme.Spacing.md) {
                    ShareLink(item: inviteURL) {
                        Text(GoDiveFriendsPresentation.shareLinkButtonTitle)
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        UIPasteboard.general.string = inviteURL.absoluteString
                        didCopy = true
                    } label: {
                        Text(didCopy ? "Copied" : GoDiveFriendsPresentation.copyLinkButtonTitle)
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Button(GoDiveFriendsPresentation.revokeInviteButtonTitle, role: .destructive) {
                    onRevoke()
                }
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, AppTheme.Spacing.sm)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task(id: inviteURL) {
            qrImage = GoDiveFriendInviteQRCodeRenderer.image(
                for: inviteURL,
                dimension: qrSize
            )
        }
        .accessibilityIdentifier("FriendInviteShare.Root")
    }
}
