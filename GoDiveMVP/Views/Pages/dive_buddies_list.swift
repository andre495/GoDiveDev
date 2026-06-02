import SwiftData
import SwiftUI

/// Owner **`DiveBuddy`** roster — pushed from **Profile**.
struct DiveBuddiesListView: View {
    @Environment(AccountSession.self) private var accountSession

    @Query(
        sort: [SortDescriptor(\DiveBuddy.displayName, order: .forward)]
    )
    private var allBuddies: [DiveBuddy]

    private var ownerProfileID: UUID? {
        accountSession.currentProfile?.id
    }

    private var ownedBuddies: [DiveBuddy] {
        guard let ownerProfileID else { return [] }
        return allBuddies.filter { $0.ownerProfileID == ownerProfileID }
    }

    var body: some View {
        AppPage(
            title: "Dive Buddies",
            showsBackButton: true,
            scrollContentUnderHeader: true,
            showsWaterBubbleBackground: true
        ) {
            if ownedBuddies.isEmpty {
                AppScrollUnderHeaderEmptyState {
                    emptyState
                }
            } else {
                buddyList
            }
        }
        .hidesBottomTabBarWhenPushed()
        .accessibilityIdentifier("DiveBuddiesList.Root")
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "person.2")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.Colors.accent.opacity(0.85))

            Text("No dive buddies yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text("Tag buddies on a dive from the dive overview to build your roster.")
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.lg)
        .accessibilityIdentifier("DiveBuddiesList.EmptyState")
    }

    private var buddyList: some View {
        AppScrollUnderHeaderList(listAccessibilityIdentifier: "DiveBuddiesList.List") {
            ForEach(ownedBuddies, id: \.id) { buddy in
                NavigationLink {
                    ViewDiveBuddyDetails(buddy: buddy)
                } label: {
                    DiveBuddyListRowView(
                        buddy: buddy,
                        sharedDiveCount: sharedDiveCount(for: buddy)
                    )
                }
                .buttonStyle(.plain)
                .navigationLinkIndicatorVisibility(.hidden)
                .listRowInsets(AppScrollUnderHeaderListLayout.horizontalRowInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
    }

    private func sharedDiveCount(for buddy: DiveBuddy) -> Int {
        guard let ownerProfileID else { return 0 }
        return DiveBuddyRosterPresentation.sharedDiveCount(for: buddy, ownerProfileID: ownerProfileID)
    }
}

// MARK: - Row

private struct DiveBuddyListRowView: View {
    let buddy: DiveBuddy
    let sharedDiveCount: Int

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            ProfileAvatarView(
                profilePhoto: buddy.profilePhoto,
                diameter: 48,
                iconFont: .title3
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(buddy.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)

                Text(DiveBuddyRosterPresentation.listSubtitle(sharedDiveCount: sharedDiveCount))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(AppTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(buddy.displayName), \(DiveBuddyRosterPresentation.listSubtitle(sharedDiveCount: sharedDiveCount))")
    }
}
