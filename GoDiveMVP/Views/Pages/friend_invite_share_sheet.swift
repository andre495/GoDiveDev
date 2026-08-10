import SwiftUI
import UIKit

/// QR + share / copy for a friend invite link.
struct FriendInviteShareSheet: View {
    let inviteURL: URL

    @Environment(\.dismiss) private var dismiss

    @State private var didCopy = false
    @State private var qrImage: UIImage?

    private var qrSize: CGFloat { FriendInviteShareSheetPresentation.qrDisplaySize }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    Group {
                        if let qrImage {
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: qrSize, height: qrSize)
                                .accessibilityLabel("Friend invite QR code")
                        } else {
                            GoDiveRotateLoadingIndicator(size: .compact)
                                .frame(width: qrSize, height: qrSize)
                                .accessibilityLabel("Generating friend invite QR code")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppTheme.Spacing.sm)

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

                    Text(GoDiveFriendsPresentation.inviteExpiresFooter)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, AppTheme.Spacing.sm)
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.bottom, AppTheme.Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollContentBackground(.hidden)
            .navigationTitle(GoDiveFriendsPresentation.inviteSheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppGlassToolbarCancelButton(
                        action: { dismiss() },
                        accessibilityIdentifier: FriendInviteShareSheetPresentation.cancelAccessibilityIdentifier
                    )
                }
            }
            .task(id: inviteURL) {
                qrImage = GoDiveFriendInviteQRCodeRenderer.image(
                    for: inviteURL,
                    dimension: qrSize
                )
            }
        }
        .diveActivityOverviewPanelModalSheetPresentation()
        .accessibilityIdentifier("FriendInviteShare.Root")
    }
}
