import SwiftUI

/// Home bell → past notifications (buddy connections + friend-shared activities).
/// Rows push the friend profile or the shared activity on the **Home** stack.
struct HomeNotificationsView: View {
    let ownerProfileID: UUID?
    let onOpenFriend: (GoDiveFriendGraphService.FriendEdge) -> Void
    let onOpenActivity: (LogbookBuddyFeedPresentation.Row) -> Void

    @State private var items: [HomeNotificationsPresentation.Item] = []
    @State private var isLoading = false
    @State private var hasLoadedOnce = false

    var body: some View {
        AppPage(
            title: HomeNotificationsPresentation.pageTitle,
            showsBackButton: true,
            showsBrandWordmark: false,
            scrollContentUnderHeader: true,
            collapsibleInlineTitleHeader: true
        ) {
            HomeNotificationsListContent(
                items: items,
                isLoading: isLoading && !hasLoadedOnce,
                onOpenFriend: onOpenFriend,
                onOpenActivity: onOpenActivity,
                onRefresh: { await loadItems() }
            )
        }
        .hidesBottomTabBarWhenPushed()
        .task {
            CrashBreadcrumbTrail.noteScreen("home-notifications")
            await loadItems()
        }
    }

    @MainActor
    private func loadItems() async {
        isLoading = true
        defer { isLoading = false }
        let snapshot = await GoDiveSharedDiveProjectionSync.fetchBuddyFeedSnapshot()
        items = HomeNotificationsPresentation.items(
            friends: snapshot.friends,
            activityRows: snapshot.rows,
            currentFirebaseUID: GoDiveFirestoreUserProfileMapping.loadCachedFirebaseUID()
        )
        hasLoadedOnce = true
        if let ownerProfileID {
            HomeNotificationsLastSeenStore.markSeen(ownerProfileID: ownerProfileID)
        }
    }
}

private struct HomeNotificationsListContent: View {
    @Environment(\.appScrollUnderHeaderInsets) private var scrollInsets
    @Environment(\.appCollapsibleInlineTitleHeaderScrollOffset) private var collapsibleScrollOffsetHandler

    let items: [HomeNotificationsPresentation.Item]
    let isLoading: Bool
    let onOpenFriend: (GoDiveFriendGraphService.FriendEdge) -> Void
    let onOpenActivity: (LogbookBuddyFeedPresentation.Row) -> Void
    let onRefresh: () async -> Void

    private var topInset: CGFloat {
        scrollInsets?.top ?? AppTheme.Layout.appHeaderClearanceFallback
    }

    private var bottomInset: CGFloat {
        scrollInsets?.bottom ?? AppTheme.Spacing.md
    }

    var body: some View {
        let scroll = ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if isLoading {
                    loadingState
                } else if items.isEmpty {
                    emptyState
                } else {
                    ForEach(items) { item in
                        HomeNotificationRowView(item: item) {
                            open(item)
                        }

                        if item.id != items.last?.id {
                            Divider()
                                .padding(.leading, HomeNotificationRowView.avatarDiameter + AppTheme.Spacing.md)
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.top, topInset + AppTheme.Spacing.sm)
            .padding(.bottom, bottomInset + AppTheme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ignoresSafeArea(edges: [.top, .bottom])
        .refreshable { await onRefresh() }
        .accessibilityIdentifier("Home.Notifications.List")

        if let collapsibleScrollOffsetHandler {
            scroll.onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { offset, _ in
                collapsibleScrollOffsetHandler(offset)
            }
        } else {
            scroll
        }
    }

    private func open(_ item: HomeNotificationsPresentation.Item) {
        switch item.kind {
        case .friendConnected(let friend):
            onOpenFriend(friend)
        case .buddyActivityShared(let row):
            onOpenActivity(row)
        case .buddyActivityTaggedYou(let row):
            onOpenActivity(row)
        }
    }

    private var loadingState: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ProgressView()
            Text("Loading notifications…")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, AppTheme.Spacing.lg * 2)
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "bell.slash")
                .font(.title2)
                .foregroundStyle(AppTheme.Colors.secondaryText)
            Text(HomeNotificationsPresentation.emptyStateMessage)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, AppTheme.Spacing.lg * 2)
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
}

private struct HomeNotificationRowView: View {
    static let avatarDiameter: CGFloat = 44

    let item: HomeNotificationsPresentation.Item
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
                FriendSharedMapOwnerAvatarView(
                    displayName: item.friendDisplayName,
                    photoURL: item.friendPhotoURL,
                    diameter: Self.avatarDiameter
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.message)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 4) {
                        if let detail = item.detail {
                            Text(detail)
                                .lineLimit(1)
                            Text("·")
                        }
                        Text(item.date, format: .relative(presentation: .named))
                    }
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            .padding(.vertical, AppTheme.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the related page")
    }
}
