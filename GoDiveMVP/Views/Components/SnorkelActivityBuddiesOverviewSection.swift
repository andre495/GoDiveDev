import SwiftUI
import SwiftData

/// **Buddies** overview card on the snorkel map tab — horizontal avatars (add via section header **+**).
struct SnorkelActivityBuddiesOverviewSection: View {
    @Bindable var activity: SnorkelActivity

    @Environment(AccountSession.self) private var accountSession
    @State private var friendEdges: [GoDiveFriendGraphService.FriendEdge] = []

    private var avatarLookup: BuddyFeedAvatarLookup {
        BuddyFeedAvatarLookup.make(
            currentFirebaseUID: GoDiveFirebaseAuthSession.currentFirebaseUID(),
            currentLocalProfilePhoto: accountSession.currentProfile?.profilePhoto,
            friends: friendEdges
        )
    }

    var body: some View {
        buddiesContent
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("SnorkelOverview.BuddiesSection")
            .task {
                friendEdges = (try? await GoDiveFriendGraphService.listFriendEdges()) ?? []
            }
    }

    @ViewBuilder
    private var buddiesContent: some View {
        if activity.buddies.isEmpty {
            Text("—")
                .font(.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Buddies, none")
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.md) {
                    ForEach(activity.buddies, id: \.id) { tag in
                        buddyAvatar(for: tag)
                    }
                }
                .padding(.vertical, 2)
            }
            .horizontalChipRowTrailingScrollFade()
        }
    }

    @ViewBuilder
    private func buddyAvatar(for tag: SnorkelBuddyTag) -> some View {
        let sources: DiveBuddyAvatarChipSources = {
            if let buddy = tag.buddy {
                return DiveBuddyAvatarChipPresentation.sources(for: buddy, lookup: avatarLookup)
            }
            return DiveBuddyAvatarChipPresentation.sources(
                profilePhoto: nil,
                lookup: avatarLookup
            )
        }()
        let chip = DiveActivityBuddyAvatarChip(
            displayName: tag.displayName,
            profilePhoto: sources.localProfilePhoto,
            photoURL: sources.photoURL,
            showsGoDiveUserPin: tag.buddy.map(DiveBuddyFriendLinkPresentation.isLinkedFriend) ?? false
        )

        if DiveActivityBuddiesOverviewPresentation.shouldOpenBuddyDetail(
            buddy: tag.buddy,
            owner: accountSession.currentProfile
        ), let buddy = tag.buddy {
            NavigationLink {
                DiveBuddyOrFriendDetailView(buddy: buddy)
            } label: {
                chip
            }
            .buttonStyle(.plain)
            .navigationLinkIndicatorVisibility(.hidden)
            .accessibilityHint("Opens buddy or friend profile")
            .accessibilityIdentifier(buddyAccessibilityIdentifier(for: tag))
        } else {
            chip
                .accessibilityIdentifier(buddyAccessibilityIdentifier(for: tag))
        }
    }

    private func buddyAccessibilityIdentifier(for tag: SnorkelBuddyTag) -> String {
        if let buddyID = tag.buddy?.id ?? tag.buddyID {
            return "SnorkelOverview.Buddies.\(buddyID.uuidString)"
        }
        return "SnorkelOverview.Buddies.Tag.\(tag.id.uuidString)"
    }
}
