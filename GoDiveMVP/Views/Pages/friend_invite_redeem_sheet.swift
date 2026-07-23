import SwiftData
import SwiftUI

/// Confirm redeeming a friend invite from a deep link.
struct FriendInviteRedeemSheet: View {
    let token: String
    let onFinished: () -> Void

    @Environment(AccountSession.self) private var accountSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var profile: GoDiveFriendGraphService.PublicProfileSummary?
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var isRedeeming = false

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Text(GoDiveFriendsPresentation.redeemTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            if isLoading {
                ProgressView()
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            } else if let profile {
                Text(GoDiveFriendsPresentation.redeemMessage(displayName: profile.displayName))
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: AppTheme.Spacing.md) {
                Button(GoDiveFriendsPresentation.redeemCancelButtonTitle) {
                    dismiss()
                    onFinished()
                }
                .buttonStyle(.bordered)

                Button(GoDiveFriendsPresentation.redeemConfirmButtonTitle) {
                    Task { await redeem() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(profile == nil || isRedeeming || errorMessage != nil)
            }

            Spacer(minLength: 0)
        }
        .padding(AppTheme.Spacing.lg)
        .task { await loadPreview() }
        .accessibilityIdentifier("FriendInviteRedeem.Root")
    }

    @MainActor
    private func loadPreview() async {
        isLoading = true
        defer { isLoading = false }
        let result = await GoDiveFriendGraphService.loadInvitePreview(token: token)
        switch result {
        case .success(let pair):
            profile = pair.profile
            errorMessage = nil
        case .failure(let failure):
            profile = nil
            errorMessage = failure.message
        }
    }

    @MainActor
    private func redeem() async {
        isRedeeming = true
        defer { isRedeeming = false }
        let result = await GoDiveFriendGraphService.redeemInvite(token: token)
        switch result {
        case .success(let friendProfile):
            if let owner = accountSession.currentProfile {
                _ = GoDiveFriendBuddyLinking.upsertRosterBuddy(
                    friendUID: friendProfile.uid,
                    displayName: friendProfile.displayName,
                    photoURL: friendProfile.photoURL,
                    owner: owner,
                    modelContext: modelContext
                )
                let context = modelContext
                let ownerID = owner.id
                Task {
                    await GoDiveSharedDiveProjectionSync.republishAllOwnedDives(
                        ownerProfileID: ownerID,
                        modelContext: context,
                        assumeHasFriends: true
                    )
                }
            }
            GoDiveFriendInvitePostRedeemNavigation.scheduleOpenFriendProfile(friendProfile)
            dismiss()
            onFinished()
        case .failure(let failure):
            errorMessage = failure.message
        }
    }
}
