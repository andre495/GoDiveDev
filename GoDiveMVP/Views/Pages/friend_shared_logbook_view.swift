import SwiftUI

/// Read-only list of a friend’s shared dive projections.
struct FriendSharedLogbookView: View {
    let friend: GoDiveFriendGraphService.FriendEdge

    @State private var dives: [GoDiveSharedDiveProjectionMapping.FriendVisibleDive] = []
    @State private var isLoading = true

    var body: some View {
        AppHeaderlessPage {
            VStack(spacing: 0) {
                HStack {
                    SecondaryDestinationBackButton()
                    NavigationLink {
                        FriendProfileView(friend: friend)
                    } label: {
                        Text(friend.displayName)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, AppTheme.Spacing.sm)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if dives.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(dives) { dive in
                            NavigationLink {
                                FriendSharedDiveDetailView(dive: dive, friendName: friend.displayName)
                            } label: {
                                LogbookBuddyFeedTileView(
                                    row: LogbookBuddyFeedPresentation.Row(
                                        id: LogbookBuddyFeedPresentation.rowID(
                                            friendUID: friend.friendUID,
                                            diveDocumentID: dive.id
                                        ),
                                        friendUID: friend.friendUID,
                                        friendDisplayName: friend.displayName,
                                        dive: dive
                                    )
                                )
                            }
                            .listRowInsets(
                                EdgeInsets(
                                    top: 0,
                                    leading: AppTheme.Spacing.lg,
                                    bottom: AppTheme.Spacing.sm,
                                    trailing: AppTheme.Spacing.lg
                                )
                            )
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .hidesBottomTabBarWhenPushed()
        .task { await load() }
        .accessibilityIdentifier("FriendSharedLogbook.Root")
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text(GoDiveFriendsPresentation.sharedLogbookEmptyTitle)
                .font(.title3.weight(.semibold))
            Text(GoDiveFriendsPresentation.sharedLogbookEmptyMessage)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        dives = await GoDiveSharedDiveProjectionSync.fetchFriendSharedDives(friendUID: friend.friendUID)
    }
}
