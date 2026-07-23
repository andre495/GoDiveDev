import SwiftData
import SwiftUI

/// Owner roster + GoDive friends — **Profile → Buddies**.
struct DiveBuddiesListView: View {
    @Environment(AccountSession.self) private var accountSession
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNetworkConnectivityMonitor.self) private var networkConnectivity

    @Query private var ownedBuddies: [DiveBuddy]

    @State private var friends: [GoDiveFriendGraphService.FriendEdge] = []
    @State private var isLoadingFriends = true
    @State private var friendsLoadError: String?
    @State private var showsAddBuddySheet = false
    @State private var activeInvite: FriendInviteSharePresentation?
    @State private var isCreatingInvite = false
    @State private var friendPendingUnfriend: GoDiveFriendGraphService.FriendEdge?
    @State private var statusMessage: String?
    @State private var invitingBuddyID: UUID?

    init(ownerProfileID: UUID? = nil) {
        let filterOwnerID = ownerProfileID ?? Self.noOwnerQueryToken
        _ownedBuddies = Query(
            filter: #Predicate<DiveBuddy> { $0.ownerProfileID == filterOwnerID },
            sort: [SortDescriptor(\DiveBuddy.displayName, order: .forward)]
        )
    }

    private static let noOwnerQueryToken = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private var ownerProfileID: UUID? {
        accountSession.currentProfile?.id
    }

    private var rosterBuddies: [DiveBuddy] {
        DiveBuddySelfRepresentation.rosterBuddiesExcludingSelf(
            ownedBuddies,
            owner: accountSession.currentProfile
        )
    }

    private var mergedRows: [BuddiesListRow] {
        BuddiesListPresentation.mergedRows(
            friends: friends,
            rosterBuddies: rosterBuddies,
            sharedDiveCount: { sharedDiveCount(for: $0) }
        )
    }

    private var showsLoadingChrome: Bool {
        isLoadingFriends && mergedRows.isEmpty
    }

    @Environment(\.openBuddiesListDetailRoute) private var openBuddiesListDetailRoute

    private var usesProgrammaticBuddyDetailNavigation: Bool {
        openBuddiesListDetailRoute != nil
    }

    var body: some View {
        AppPage(
            title: BuddiesListPresentation.pageTitle,
            showsBackButton: true,
            showsBrandWordmark: false,
            scrollContentUnderHeader: true,
            collapsibleInlineTitleHeader: true,
            showsWaterBubbleBackground: true,
            trailingContent: {
                toolbarChrome
            },
            content: {
            if showsLoadingChrome {
                AppScrollUnderHeaderEmptyState {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.lg)
                }
            } else if mergedRows.isEmpty {
                AppScrollUnderHeaderEmptyState {
                    emptyState
                }
            } else {
                buddyList
            }
            }
        )
        .hidesBottomTabBarWhenPushed()
        .task { await reloadFriends(republishInBackground: true) }
        .onReceive(NotificationCenter.default.publisher(for: .goDiveFriendGraphDidChange)) { _ in
            Task { await reloadFriends(republishInBackground: true, showsLoadingUI: false) }
        }
        .sheet(isPresented: $showsAddBuddySheet) {
            DiveActivityAddBuddySheet()
        }
        .sheet(item: $activeInvite) { invite in
            FriendInviteShareSheet(
                inviteURL: invite.url,
                onRevoke: {
                    Task {
                        _ = await GoDiveFriendGraphService.revokeInvite(token: invite.token)
                        await MainActor.run {
                            activeInvite = nil
                        }
                    }
                }
            )
            .friendInviteShareSheetPresentation()
        }
        .alert(
            GoDiveFriendsPresentation.unfriendConfirmTitle,
            isPresented: Binding(
                get: { friendPendingUnfriend != nil },
                set: { if !$0 { friendPendingUnfriend = nil } }
            )
        ) {
            Button(GoDiveFriendsPresentation.redeemCancelButtonTitle, role: .cancel) {
                friendPendingUnfriend = nil
            }
            Button(GoDiveFriendsPresentation.unfriendButtonTitle, role: .destructive) {
                if let edge = friendPendingUnfriend {
                    Task { await unfriend(edge) }
                }
            }
        }
        .accessibilityIdentifier("DiveBuddiesList.Root")
    }

    private var toolbarChrome: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            inviteToolbarButton
            addBuddyToolbarButton
        }
        .appLiquidGlassChromeContainer()
    }

    private var addBuddyToolbarButton: some View {
        Button {
            showsAddBuddySheet = true
        } label: {
            Image(systemName: "plus")
                .appToolbarIconButtonLabel()
        }
        .appStandaloneIconButtonStyle()
        .accessibilityLabel("Add buddy")
        .accessibilityIdentifier("DiveBuddiesList.AddNewBuddy")
    }

    private var inviteToolbarButton: some View {
        Button {
            Task { await createInvite() }
        } label: {
            Image(systemName: "qrcode")
                .appToolbarIconButtonLabel()
        }
        .appStandaloneIconButtonStyle()
        .accessibilityLabel(GoDiveFriendsPresentation.addFriendAccessibilityLabel)
        .accessibilityIdentifier("DiveBuddiesList.InviteQRButton")
        .disabled(!networkConnectivity.isConnected || isCreatingInvite)
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "person.2")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.Colors.accent.opacity(0.85))

            Text(BuddiesListPresentation.emptyTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text(friendsLoadError ?? BuddiesListPresentation.emptyMessage)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)

            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.lg)
        .accessibilityIdentifier("DiveBuddiesList.EmptyState")
    }

    private var buddyList: some View {
        AppScrollUnderHeaderList(listAccessibilityIdentifier: "DiveBuddiesList.List") {
            if let friendsLoadError, !rosterBuddies.isEmpty {
                Text(friendsLoadError)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .listRowInsets(AppScrollUnderHeaderListLayout.horizontalRowInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            ForEach(mergedRows) { row in
                BuddiesListRowView(
                    row: row,
                    isInviting: invitingBuddyID == row.buddy?.id,
                    usesProgrammaticDetailNavigation: usesProgrammaticBuddyDetailNavigation,
                    onOpenProgrammaticRoute: { route in
                        openBuddiesListDetailRoute?(route)
                    },
                    onInvite: {
                        guard let buddy = row.buddy else { return }
                        Task { await inviteBuddyViaSMS(buddy) }
                    }
                )
                .listRowInsets(AppScrollUnderHeaderListLayout.horizontalRowInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if let edge = row.friendEdge {
                        Button(GoDiveFriendsPresentation.unfriendButtonTitle, role: .destructive) {
                            friendPendingUnfriend = edge
                        }
                    }
                }
            }
        }
    }

    private func sharedDiveCount(for buddy: DiveBuddy) -> Int {
        guard let ownerProfileID else { return 0 }
        return DiveBuddyRosterPresentation.sharedDiveCount(for: buddy, ownerProfileID: ownerProfileID)
    }

    @MainActor
    private func reloadFriends(republishInBackground: Bool, showsLoadingUI: Bool = true) async {
        let shouldDriveLoadingUI = showsLoadingUI || (friends.isEmpty && rosterBuddies.isEmpty)
        if shouldDriveLoadingUI {
            isLoadingFriends = true
        }
        friendsLoadError = nil
        defer {
            if shouldDriveLoadingUI {
                isLoadingFriends = false
            }
        }
        do {
            friends = try await GoDiveFriendGraphService.listFriendEdges()
            if let owner = accountSession.currentProfile {
                GoDiveFriendBuddyLinking.syncRosterLinks(
                    friends: friends,
                    owner: owner,
                    modelContext: modelContext
                )
            }
            if republishInBackground, let ownerID = accountSession.currentProfile?.id {
                scheduleBackgroundRepublish(ownerProfileID: ownerID, hasFriends: !friends.isEmpty)
            }
        } catch {
            friendsLoadError = GoDiveFriendsPresentation.firebaseUnavailableMessage
            if friends.isEmpty {
                friends = []
            }
        }
    }

    @MainActor
    private func scheduleBackgroundRepublish(ownerProfileID: UUID, hasFriends: Bool) {
        guard hasFriends else { return }
        let context = modelContext
        Task {
            await GoDiveSharedDiveProjectionSync.republishAllOwnedDives(
                ownerProfileID: ownerProfileID,
                modelContext: context,
                assumeHasFriends: true
            )
        }
    }

    @MainActor
    private func createInvite() async {
        guard !isCreatingInvite else { return }
        isCreatingInvite = true
        defer { isCreatingInvite = false }

        let result = await GoDiveFriendGraphService.createInvite()
        switch result {
        case .success(let pair):
            activeInvite = FriendInviteSharePresentation(token: pair.token, url: pair.url)
            statusMessage = nil
        case .failure(let failure):
            statusMessage = failure.message
        }
    }

    @MainActor
    private func inviteBuddyViaSMS(_ buddy: DiveBuddy) async {
        if invitingBuddyID == buddy.id { return }
        guard networkConnectivity.isConnected else {
            statusMessage = GoDiveFriendsPresentation.firebaseUnavailableMessage
            return
        }
        invitingBuddyID = buddy.id
        defer { invitingBuddyID = nil }

        let result = await GoDiveFriendGraphService.createInvite()
        switch result {
        case .success(let pair):
            let recipients = DiveBuddyContactSMSPresentation.smsRecipients(
                contactsIdentifier: buddy.contactsIdentifier
            )
            let body = BuddiesListPresentation.smsBody(
                inviteURL: pair.url,
                buddyDisplayName: buddy.displayName
            )
            FriendInviteSMSComposePresentation.present(recipients: recipients, body: body)
            statusMessage = nil
        case .failure(let failure):
            statusMessage = failure.message
        }
    }

    @MainActor
    private func unfriend(_ edge: GoDiveFriendGraphService.FriendEdge) async {
        friendPendingUnfriend = nil
        let outcome = await GoDiveFriendGraphService.unfriend(friendshipID: edge.friendshipID)
        if case .success = outcome, let ownerID = accountSession.currentProfile?.id {
            GoDiveFriendBuddyLinking.clearLink(
                friendUID: edge.friendUID,
                ownerProfileID: ownerID,
                modelContext: modelContext
            )
            await reloadFriends(republishInBackground: true, showsLoadingUI: false)
        }
    }
}

// MARK: - Row

private struct BuddiesListRowView: View {
    let row: BuddiesListRow
    let isInviting: Bool
    let usesProgrammaticDetailNavigation: Bool
    let onOpenProgrammaticRoute: (BuddiesListNavigationRoute) -> Void
    let onInvite: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            buddyRowNavigationLink

            if showsInviteButton {
                inviteButton
            }
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.displayName), \(row.subtitle)")
        .accessibilityHint(showsInviteButton ? "Opens buddy details. Invite sends a link separately." : "")
    }

    @ViewBuilder
    private var buddyRowNavigationLink: some View {
        if let route = row.navigationRoute {
            if usesProgrammaticDetailNavigation {
                Button {
                    onOpenProgrammaticRoute(route)
                } label: {
                    rowLinkLabel
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                NavigationLink {
                    BuddiesListNavigationDestinationView(route: route)
                } label: {
                    rowLinkLabel
                }
                .buttonStyle(.plain)
                .navigationLinkIndicatorVisibility(.hidden)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            rowLinkLabel
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var rowLinkLabel: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            BuddiesListAvatarView(row: row)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)

                if row.isFriend, let total = row.friendTotalDiveCount {
                    Text(BuddiesListPresentation.friendTotalDivesLabel(total))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .lineLimit(1)
                }

                Text(row.divesTogetherSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(1)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var showsInviteButton: Bool {
        row.buddy != nil && !row.isFriend
    }

    private var inviteButton: some View {
        Button(action: onInvite) {
            Group {
                if isInviting {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Text(BuddiesListPresentation.inviteButtonTitle)
                        .font(.caption2.weight(.semibold))
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .fixedSize(horizontal: true, vertical: false)
        .disabled(isInviting)
        .accessibilityLabel(BuddiesListPresentation.inviteAccessibilityLabel)
        .accessibilityIdentifier("DiveBuddiesList.Invite.\(row.buddy?.id.uuidString ?? "unknown")")
    }
}

private struct BuddiesListAvatarView: View {
    let row: BuddiesListRow

    private let diameter: CGFloat = 48

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            avatarContent
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())

            if row.isFriend {
                Image(systemName: "person.crop.circle.fill.badge.checkmark")
                    .font(.system(size: 18))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, AppTheme.Colors.accent)
                    .background(Circle().fill(.white).frame(width: 14, height: 14))
                    .offset(x: 4, y: 4)
                    .accessibilityLabel(BuddiesListPresentation.friendBadgeAccessibilityLabel)
            }
        }
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let buddy = row.buddy {
            ProfileAvatarView(
                profilePhoto: buddy.profilePhoto,
                diameter: diameter,
                iconFont: .title3,
                placeholderInitials: DiveBuddyPresentation.initials(from: buddy.displayName)
            )
        } else if let urlString = row.friendEdge?.photoURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    friendInitialsPlaceholder
                }
            }
        } else {
            friendInitialsPlaceholder
        }
    }

    private var friendInitialsPlaceholder: some View {
        ZStack {
            Circle()
                .fill(AppTheme.Colors.accent.opacity(0.2))
            Text(DiveBuddyPresentation.initials(from: row.displayName))
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.accent)
        }
    }
}
