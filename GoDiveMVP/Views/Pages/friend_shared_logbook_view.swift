import SwiftUI

/// Read-only list of a friend’s shared dive projections.
struct FriendSharedLogbookView: View {
    let friend: GoDiveFriendGraphService.FriendEdge

    @Environment(AccountSession.self) private var accountSession
    @State private var rows: [LogbookBuddyFeedPresentation.Row] = []
    @State private var isLoading = true
    @State private var avatarLookup: BuddyFeedAvatarLookup = .empty
    /// Comment icon → push detail with comments sheet (caption still uses nested `NavigationLink`).
    @State private var commentsDetailRow: LogbookBuddyFeedPresentation.Row?
    /// “with” avatar tap → Map scrolled to tagged buddies.
    @State private var taggedBuddiesDetailRow: LogbookBuddyFeedPresentation.Row?

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
                    GoDiveRotateLoadingIndicator()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if rows.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(rows) { row in
                            LogbookBuddyFeedNavigableTile(
                                row: row,
                                avatarLookup: avatarLookup,
                                onOpenFriendProfile: nil,
                                onToggleLike: {
                                    toggleLike(row)
                                },
                                onOpenComments: {
                                    commentsDetailRow = row
                                },
                                onOpenTaggedBuddies: {
                                    taggedBuddiesDetailRow = row
                                }
                            ) {
                                NavigationLink {
                                    FriendSharedDiveDetailView(
                                        dive: row.dive,
                                        friendName: friend.displayName,
                                        friendPhotoURL: friend.photoURL,
                                        friendUID: friend.friendUID
                                    )
                                } label: {
                                    LogbookBuddyFeedTileView(
                                        row: row,
                                        part: .caption,
                                        avatarLookup: avatarLookup
                                    )
                                }
                                .buttonStyle(.plain)
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
        .navigationDestination(item: $commentsDetailRow) { row in
            FriendSharedDiveDetailView(
                dive: row.dive,
                friendName: friend.displayName,
                friendPhotoURL: friend.photoURL,
                friendUID: friend.friendUID,
                opensCommentsOnAppear: true
            )
        }
        .navigationDestination(item: $taggedBuddiesDetailRow) { row in
            FriendSharedDiveDetailView(
                dive: row.dive,
                friendName: friend.displayName,
                friendPhotoURL: friend.photoURL,
                friendUID: friend.friendUID,
                scrollToTaggedBuddiesOnAppear: true
            )
        }
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
        let friends = (try? await GoDiveFriendGraphService.listFriendEdges()) ?? [friend]
        avatarLookup = BuddyFeedAvatarLookup.make(
            currentFirebaseUID: GoDiveFirebaseAuthSession.currentFirebaseUID(),
            currentLocalProfilePhoto: accountSession.currentProfile?.profilePhoto,
            friends: friends
        )
        let dives = await GoDiveSharedDiveProjectionSync.fetchFriendSharedDives(
            friendUID: friend.friendUID
        )
        let baseRows = dives.map { dive in
            LogbookBuddyFeedPresentation.Row(
                id: LogbookBuddyFeedPresentation.rowID(
                    friendUID: friend.friendUID,
                    diveDocumentID: dive.id
                ),
                friendUID: friend.friendUID,
                friendDisplayName: friend.displayName,
                friendPhotoURL: friend.photoURL,
                dive: dive
            )
        }
        let likedRowIDs = await GoDiveSharedActivityLikeSync.likedRowIDsForCurrentUser(among: baseRows)
        rows = LogbookBuddyFeedPresentation.enrichingRows(baseRows, likedRowIDs: likedRowIDs)
    }

    @MainActor
    private func toggleLike(_ row: LogbookBuddyFeedPresentation.Row) {
        guard let latest = rows.first(where: { $0.id == row.id }) else { return }
        let nextLiked = !latest.currentUserHasLiked
        let optimistic = LogbookBuddyFeedPresentation.rowApplyingLikeToggle(latest, liked: nextLiked)
        rows = LogbookBuddyFeedPresentation.replacingRow(optimistic, in: rows)
        let displayName = accountSession.currentProfile?.displayName ?? "A dive buddy"
        let ownerUID = latest.friendUID
        let activityID = latest.dive.id
        let rowID = latest.id
        Task { @MainActor in
            let succeeded = await GoDiveSharedActivityLikeSync.setLiked(
                ownerUID: ownerUID,
                activityID: activityID,
                liked: nextLiked,
                likerDisplayName: displayName
            )
            guard let current = rows.first(where: { $0.id == rowID }) else { return }
            if !succeeded {
                if current.currentUserHasLiked == nextLiked {
                    rows = LogbookBuddyFeedPresentation.replacingRow(latest, in: rows)
                }
                return
            }
            if current.currentUserHasLiked != nextLiked {
                _ = await GoDiveSharedActivityLikeSync.setLiked(
                    ownerUID: ownerUID,
                    activityID: activityID,
                    liked: current.currentUserHasLiked,
                    likerDisplayName: displayName
                )
            }
        }
    }
}
