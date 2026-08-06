import SwiftUI

/// Home bell → past notifications (buddy connections, shared activities, likes, comments, mentions).
/// Rows push the friend profile, a shared activity, or your own liked/commented/mentioned activity.
struct HomeNotificationsView: View {
    let ownerProfileID: UUID?
    let onOpenFriend: (GoDiveFriendGraphService.FriendEdge) -> Void
    let onOpenActivity: (LogbookBuddyFeedPresentation.Row) -> Void
    let onOpenOwnedActivity: (HomeNotificationsPresentation.OwnedActivityTarget) -> Void
    let onOpenMention: (HomeNotificationsPresentation.MentionTarget) -> Void

    @State private var items: [HomeNotificationsPresentation.Item] = []
    @State private var isLoading = false
    @State private var hasLoadedOnce = false
    /// Last-seen watermark from **before** this visit — used so rows stay unread-styled
    /// until the user leaves (markSeen still clears the bell on open).
    @State private var unreadBaselineAt: Date?
    @State private var didCaptureUnreadBaseline = false

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
                unreadBaselineAt: unreadBaselineAt,
                isLoading: isLoading && !hasLoadedOnce,
                onOpenFriend: onOpenFriend,
                onOpenActivity: onOpenActivity,
                onOpenOwnedActivity: onOpenOwnedActivity,
                onOpenMention: onOpenMention,
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
        if !didCaptureUnreadBaseline {
            if let ownerProfileID {
                unreadBaselineAt = HomeNotificationsLastSeenStore.lastSeenAt(
                    ownerProfileID: ownerProfileID
                )
            }
            didCaptureUnreadBaseline = true
        }
        async let snapshotTask = GoDiveSharedDiveProjectionSync.fetchBuddyFeedSnapshot()
        async let ownedSocialTask = HomeNotificationsOwnedSocialSync.fetchEvents()
        let snapshot = await snapshotTask
        async let mentionTask = HomeNotificationsMentionSync.fetchEvents(feedRows: snapshot.rows)
        let ownedSocial = await ownedSocialTask
        let mentions = await mentionTask
        items = HomeNotificationsPresentation.items(
            friends: snapshot.friends,
            activityRows: snapshot.rows,
            ownedSocialEvents: ownedSocial,
            mentionEvents: mentions,
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
    let unreadBaselineAt: Date?
    let isLoading: Bool
    let onOpenFriend: (GoDiveFriendGraphService.FriendEdge) -> Void
    let onOpenActivity: (LogbookBuddyFeedPresentation.Row) -> Void
    let onOpenOwnedActivity: (HomeNotificationsPresentation.OwnedActivityTarget) -> Void
    let onOpenMention: (HomeNotificationsPresentation.MentionTarget) -> Void
    let onRefresh: () async -> Void

    private var sections: HomeNotificationsPresentation.Sections {
        HomeNotificationsPresentation.sections(
            items: items,
            lastSeenAt: unreadBaselineAt
        )
    }

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
                    notificationSections
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

    @ViewBuilder
    private var notificationSections: some View {
        let split = sections

        sectionHeader(HomeNotificationsPresentation.newSectionTitle)
            .accessibilityIdentifier("Home.Notifications.NewSection")

        if split.newItems.isEmpty {
            noNewNotificationsPlaceholder
        } else {
            notificationRows(split.newItems, unreadBaselineAt: unreadBaselineAt)
        }

        if !split.older.isEmpty {
            sectionHeader(HomeNotificationsPresentation.olderSectionTitle)
                .padding(.top, AppTheme.Spacing.lg)
                .accessibilityIdentifier("Home.Notifications.OlderSection")

            notificationRows(split.older, unreadBaselineAt: unreadBaselineAt)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.tabUnselected)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, AppTheme.Spacing.sm)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func notificationRows(
        _ rows: [HomeNotificationsPresentation.Item],
        unreadBaselineAt: Date?
    ) -> some View {
        ForEach(Array(rows.enumerated()), id: \.element.id) { index, item in
            HomeNotificationRowView(
                item: item,
                isUnread: HomeNotificationsPresentation.isUnread(
                    itemDate: item.date,
                    lastSeenAt: unreadBaselineAt
                )
            ) {
                open(item)
            }

            if index < rows.count - 1 {
                Divider()
                    .padding(.leading, HomeNotificationRowView.avatarDiameter + AppTheme.Spacing.md)
            }
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
        case .buddyActivityLiked(let target), .buddyActivityCommented(let target):
            onOpenOwnedActivity(target)
        case .buddyActivityMentioned(let target):
            onOpenMention(target)
        }
    }

    private var loadingState: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            GoDiveRotateLoadingIndicator()
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

    private var noNewNotificationsPlaceholder: some View {
        Text(HomeNotificationsPresentation.noNewNotificationsMessage)
            .font(.subheadline)
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, AppTheme.Spacing.sm)
            .accessibilityIdentifier("Home.Notifications.NoNewPlaceholder")
    }
}

private struct HomeNotificationRowView: View {
    static let avatarDiameter: CGFloat = 44

    let item: HomeNotificationsPresentation.Item
    let isUnread: Bool
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
                        .font(
                            .body.weight(
                                HomeNotificationsPresentation.usesSemiboldTitle(isUnread: isUnread)
                                    ? .semibold
                                    : .regular
                            )
                        )
                        .foregroundStyle(
                            isUnread ? AppTheme.Colors.textPrimary : AppTheme.Colors.secondaryText
                        )
                        .multilineTextAlignment(.leading)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        if let detail = item.detail {
                            Text(detail)
                                // Comment previews need a bit more room than a site name.
                                .lineLimit(commentDetailLineLimit(for: item.kind))
                            Text("·")
                        }
                        Text(item.date, format: .relative(presentation: .named))
                            .layoutPriority(1)
                    }
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(isUnread ? .semibold : .regular))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            .padding(.vertical, AppTheme.Spacing.sm)
            .opacity(HomeNotificationsPresentation.rowOpacity(isUnread: isUnread))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens the related page")
    }

    private var accessibilityLabel: String {
        let status = isUnread ? "Unread" : "Read"
        if let detail = item.detail {
            return "\(status). \(item.message). \(detail)"
        }
        return "\(status). \(item.message)"
    }

    private func commentDetailLineLimit(for kind: HomeNotificationsPresentation.Item.Kind) -> Int {
        switch kind {
        case .buddyActivityCommented, .buddyActivityMentioned:
            return 2
        default:
            return 1
        }
    }
}
