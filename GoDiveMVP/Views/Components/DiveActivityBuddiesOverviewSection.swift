import SwiftUI
import SwiftData

/// **Buddies** overview card — horizontal avatars (add via section header **+**).
struct DiveActivityBuddiesOverviewSection: View {
    @Bindable var activity: DiveActivity

    @Environment(AccountSession.self) private var accountSession

    var body: some View {
        buddiesContent
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("DiveOverview.BuddiesSection")
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
    private func buddyAvatar(for tag: DiveBuddyTag) -> some View {
        let chip = DiveActivityBuddyAvatarChip(
            displayName: tag.displayName,
            profilePhoto: tag.buddy?.profilePhoto
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

    private func buddyAccessibilityIdentifier(for tag: DiveBuddyTag) -> String {
        if let buddyID = tag.buddy?.id ?? tag.buddyID {
            return "DiveOverview.Buddies.\(buddyID.uuidString)"
        }
        return "DiveOverview.Buddies.Tag.\(tag.id.uuidString)"
    }
}
