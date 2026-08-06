import SwiftUI

/// Identifies which shared activity’s comment thread to present.
struct BuddyActivityCommentsSheetTarget: Identifiable, Equatable, Hashable {
    var ownerUID: String
    var activityID: String
    var seedCommentCount: Int
    /// When `true`, focus the compose field after the sheet presents.
    var activatesKeyboard: Bool = false

    var id: String {
        "\(ownerUID)_\(activityID)_\(activatesKeyboard ? "kb" : "view")"
    }
}

/// Scrollable comment thread with a pinned bottom compose field (Buddy Feed / detail sheet).
struct BuddyActivityCommentsSheet: View {
    let ownerUID: String
    let activityID: String
    var authorDisplayName: String
    /// Focus the bottom compose field when the sheet appears (detail “Add a comment…” entry).
    var activatesKeyboard: Bool = false
    /// Seed from Buddy Feed (friend graph + Profile photo); refreshed on appear.
    var avatarLookup: BuddyFeedAvatarLookup = .empty
    var onCommentCountChanged: ((Int) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(AccountSession.self) private var accountSession
    @State private var comments: [GoDiveSharedActivityCommentSync.Comment] = []
    @State private var isLoading = true
    @State private var draftText = ""
    @State private var isSending = false
    @State private var mentionFriends: [GoDiveFriendGraphService.FriendEdge] = []
    @State private var resolvedAvatarLookup: BuddyFeedAvatarLookup
    @FocusState private var isComposeFocused: Bool

    init(
        ownerUID: String,
        activityID: String,
        authorDisplayName: String,
        activatesKeyboard: Bool = false,
        avatarLookup: BuddyFeedAvatarLookup = .empty,
        onCommentCountChanged: ((Int) -> Void)? = nil
    ) {
        self.ownerUID = ownerUID
        self.activityID = activityID
        self.authorDisplayName = authorDisplayName
        self.activatesKeyboard = activatesKeyboard
        self.avatarLookup = avatarLookup
        self.onCommentCountChanged = onCommentCountChanged
        _resolvedAvatarLookup = State(initialValue: avatarLookup)
    }

    var body: some View {
        NavigationStack {
            BuddyActivityCommentThreadContent(
                comments: comments,
                isLoading: isLoading,
                draftText: $draftText,
                isSending: isSending,
                isComposeFocused: $isComposeFocused,
                avatarLookup: resolvedAvatarLookup,
                mentionFriends: mentionFriends,
                onSend: sendComment
            )
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppSheetToolbarCloseButton(
                        action: {
                            isComposeFocused = false
                            dismiss()
                        },
                        accessibilityIdentifier: "BuddyActivityCommentsSheet.Close"
                    )
                }
            }
        }
        .diveActivityOverviewPanelModalSheetPresentation()
        .task(id: "\(ownerUID)_\(activityID)_\(activatesKeyboard)") {
            await refreshAvatarLookup()
            await loadComments()
            await activateKeyboardIfNeeded()
        }
        .accessibilityIdentifier("BuddyActivityCommentsSheet.Root")
    }

    @MainActor
    private func refreshAvatarLookup() async {
        let friends = (try? await GoDiveFriendGraphService.listFriendEdges()) ?? []
        mentionFriends = friends
        let sessionLookup = BuddyFeedAvatarLookup.make(
            currentFirebaseUID: GoDiveFirebaseAuthSession.currentFirebaseUID(),
            currentLocalProfilePhoto: accountSession.currentProfile?.profilePhoto,
            friends: friends
        )
        resolvedAvatarLookup = BuddyFeedAvatarLookup.merging(
            seed: avatarLookup,
            session: sessionLookup
        )
    }

    @MainActor
    private func activateKeyboardIfNeeded() async {
        guard activatesKeyboard else {
            isComposeFocused = false
            return
        }
        // Let the blue modal finish presenting before focusing the field.
        try? await Task.sleep(
            for: .milliseconds(BuddyActivityCommentsPresentation.keyboardActivationDelayMilliseconds)
        )
        guard !Task.isCancelled else { return }
        isComposeFocused = true
    }

    @MainActor
    private func loadComments() async {
        isLoading = true
        defer { isLoading = false }
        comments = await GoDiveSharedActivityCommentSync.fetchComments(
            ownerUID: ownerUID,
            activityID: activityID
        )
        onCommentCountChanged?(comments.count)
    }

    @MainActor
    private func sendComment() {
        guard !isSending else { return }
        let text = draftText
        guard GoDiveSharedActivityCommentSync.sanitizedCommentText(text) != nil else { return }
        let authorUID = GoDiveFirebaseAuthSession.currentFirebaseUID()
        let mentionedUIDs = GoDiveMentionPresentation.mentionedUIDs(
            in: text,
            friends: mentionFriends,
            excludingUID: authorUID
        )
        isSending = true
        Task { @MainActor in
            defer { isSending = false }
            guard let posted = await GoDiveSharedActivityCommentSync.postComment(
                ownerUID: ownerUID,
                activityID: activityID,
                text: text,
                displayName: authorDisplayName,
                mentionedUIDs: mentionedUIDs
            ) else { return }
            draftText = ""
            isComposeFocused = false
            comments.append(posted)
            onCommentCountChanged?(comments.count)
        }
    }
}

/// Inline or sheet comment list + pinned compose row.
struct BuddyActivityCommentThreadContent: View {
    let comments: [GoDiveSharedActivityCommentSync.Comment]
    var isLoading: Bool = false
    @Binding var draftText: String
    var isSending: Bool = false
    var isComposeFocused: FocusState<Bool>.Binding
    var avatarLookup: BuddyFeedAvatarLookup = .empty
    var mentionFriends: [GoDiveFriendGraphService.FriendEdge] = []
    var onSend: () -> Void

    private var activeMention: GoDiveMentionPresentation.ActiveMention? {
        GoDiveMentionPresentation.activeMention(
            in: draftText,
            utf16Caret: (draftText as NSString).length,
            friends: mentionFriends
        )
    }

    private var mentionSuggestions: [GoDiveFriendGraphService.FriendEdge] {
        guard let active = activeMention else { return [] }
        return GoDiveMentionPresentation.matchingFriends(
            query: active.query,
            friends: mentionFriends
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if isLoading, comments.isEmpty {
                    GoDiveRotateLoadingIndicator()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if comments.isEmpty {
                    Text("No comments yet")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                            ForEach(comments) { comment in
                                BuddyActivityCommentRow(
                                    comment: comment,
                                    avatarLookup: avatarLookup,
                                    mentionDisplayNames: mentionFriends.map(\.displayName)
                                )
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.vertical, AppTheme.Spacing.sm)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
                .overlay(AppTheme.Colors.tabUnselected.opacity(0.18))

            if !mentionSuggestions.isEmpty {
                GoDiveMentionAutocompleteList(friends: mentionSuggestions) { friend in
                    insertMention(friend)
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.sm)
            }

            composeBar
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, AppTheme.Spacing.sm)
        }
    }

    private var composeBar: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            TextField(
                BuddyActivityCommentsPresentation.composePlaceholder,
                text: draftBinding,
                axis: .vertical
            )
                .lineLimit(1...4)
                .focused(isComposeFocused)
                .textFieldStyle(.plain)
                .padding(.horizontal, AppTheme.Spacing.sm)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.Colors.surfaceElevated.opacity(0.55))
                )

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        canSend ? AppTheme.Colors.accent : AppTheme.Colors.tabUnselected.opacity(0.45)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel("Send comment")
        }
    }

    private func insertMention(_ friend: GoDiveFriendGraphService.FriendEdge) {
        guard let active = activeMention else { return }
        let insertion = GoDiveMentionPresentation.insertMention(
            displayName: friend.displayName,
            into: draftText,
            active: active
        )
        draftText = String(
            insertion.text.prefix(GoDiveSharedActivityCommentSync.maxCommentTextLength)
        )
    }

    private var draftBinding: Binding<String> {
        Binding(
            get: { draftText },
            set: { newValue in
                draftText = String(newValue.prefix(GoDiveSharedActivityCommentSync.maxCommentTextLength))
            }
        )
    }

    private var canSend: Bool {
        !isSending
            && GoDiveSharedActivityCommentSync.sanitizedCommentText(draftText) != nil
    }
}

/// Plain-text comment row (name + relative time + body).
struct BuddyActivityCommentRow: View {
    let comment: GoDiveSharedActivityCommentSync.Comment
    var avatarLookup: BuddyFeedAvatarLookup = .empty
    var mentionDisplayNames: [String] = []

    var body: some View {
        let resolved = BuddyFeedAvatarPresentation.resolve(
            firebaseUID: comment.authorUID,
            lookup: avatarLookup
        )
        return HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            FriendSharedMapOwnerAvatarView(
                displayName: comment.displayName,
                photoURL: resolved.photoURL,
                diameter: 32,
                showsGoDiveUserPin: true,
                localProfilePhoto: resolved.localProfilePhoto
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                    Text(comment.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .lineLimit(1)

                    if let timestamp = LogbookBuddyFeedPresentation.commentTimestampText(
                        createdAt: comment.createdAt
                    ) {
                        Text(timestamp)
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                }

                GoDiveMentionText(
                    text: comment.text,
                    knownDisplayNames: mentionDisplayNames,
                    font: .subheadline
                )
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(comment.displayName): \(comment.text)")
    }
}

/// Shared copy / timing for comment sheet + detail compose entry.
enum BuddyActivityCommentsPresentation: Sendable {
    nonisolated static let composePlaceholder = "Add a comment…"
    nonisolated static let keyboardActivationDelayMilliseconds = 180
    /// Delay after shared-activity push so the detail is on-screen before the comments sheet.
    nonisolated static let openCommentsAfterNavigationDelayMilliseconds = 280
    nonisolated static let detailComposePromptAccessibilityIdentifier =
        "FriendSharedActivity.CommentComposePrompt"

    /// One-shot consume for feed → detail → comments navigation.
    nonisolated static func shouldPresentCommentsOnAppear(
        opensCommentsOnAppear: Bool,
        alreadyConsumed: Bool
    ) -> Bool {
        opensCommentsOnAppear && !alreadyConsumed
    }
}

/// Map-panel social block (large detent): like + comment icons, then a compose prompt.
/// Sits above notes / marine life / buddies. Comment icon opens the thread (keyboard off);
/// the prompt opens it focused. Also used on **owned** shared activities (like disabled).
struct FriendSharedActivityMapSocialSection: View {
    let ownerUID: String
    let activityID: String
    let seedLikeCount: Int
    let seedCommentCount: Int
    let authorDisplayName: String
    /// When true (Buddy Feed comment icon → detail), present the thread once after appear.
    var opensCommentsOnAppear: Bool = false
    /// Cleared on the parent so leaving/returning to Map does not re-present the sheet.
    var onOpenCommentsOnAppearConsumed: (() -> Void)? = nil
    /// Owners cannot like their own shared activity; still show tallies + comments.
    var allowsLiking: Bool = true
    var avatarLookup: BuddyFeedAvatarLookup = .empty

    @Environment(AccountSession.self) private var accountSession
    @State private var isLiked = false
    @State private var likeCount: Int
    @State private var commentCount: Int
    @State private var likeWriteInFlight = false
    @State private var commentsSheetTarget: BuddyActivityCommentsSheetTarget?
    @State private var didConsumeOpenCommentsOnAppear = false
    @State private var resolvedAvatarLookup: BuddyFeedAvatarLookup

    init(
        ownerUID: String,
        activityID: String,
        seedLikeCount: Int,
        seedCommentCount: Int,
        authorDisplayName: String,
        opensCommentsOnAppear: Bool = false,
        onOpenCommentsOnAppearConsumed: (() -> Void)? = nil,
        allowsLiking: Bool = true,
        avatarLookup: BuddyFeedAvatarLookup = .empty
    ) {
        self.ownerUID = ownerUID
        self.activityID = activityID
        self.seedLikeCount = seedLikeCount
        self.seedCommentCount = seedCommentCount
        self.authorDisplayName = authorDisplayName
        self.opensCommentsOnAppear = opensCommentsOnAppear
        self.onOpenCommentsOnAppearConsumed = onOpenCommentsOnAppearConsumed
        self.allowsLiking = allowsLiking
        self.avatarLookup = avatarLookup
        _likeCount = State(initialValue: max(0, seedLikeCount))
        _commentCount = State(initialValue: max(0, seedCommentCount))
        _resolvedAvatarLookup = State(initialValue: avatarLookup)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            LogbookBuddyFeedPostActionBar(
                isLiked: isLiked,
                likeCount: likeCount,
                commentCount: commentCount,
                showsCommentControl: true,
                appliesContentPadding: false,
                iconSize: LogbookBuddyFeedTileLayout.detailActionBarIconSize,
                onToggleLike: allowsLiking ? { toggleLike() } : nil,
                onOpenComments: {
                    presentComments(activatesKeyboard: false)
                }
            )

            Button {
                presentComments(activatesKeyboard: true)
            } label: {
                Text(BuddyActivityCommentsPresentation.composePlaceholder)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppTheme.Colors.surfaceElevated.opacity(0.55))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(
                BuddyActivityCommentsPresentation.detailComposePromptAccessibilityIdentifier
            )
            .accessibilityLabel(BuddyActivityCommentsPresentation.composePlaceholder)
            .accessibilityHint("Opens comments and starts typing")
        }
        .sheet(item: $commentsSheetTarget) { target in
            BuddyActivityCommentsSheet(
                ownerUID: target.ownerUID,
                activityID: target.activityID,
                authorDisplayName: authorDisplayName,
                activatesKeyboard: target.activatesKeyboard,
                avatarLookup: resolvedAvatarLookup,
                onCommentCountChanged: { count in
                    commentCount = max(0, count)
                }
            )
        }
        .task(id: "\(ownerUID)_\(activityID)") {
            await refreshAvatarLookup()
            await refreshTalliesFromProjection()
            if allowsLiking {
                isLiked = await GoDiveSharedActivityLikeSync.isLikedByCurrentUser(
                    ownerUID: ownerUID,
                    activityID: activityID
                )
            } else {
                isLiked = false
            }
            await presentCommentsAfterNavigationIfNeeded()
        }
        .accessibilityIdentifier("FriendSharedActivity.MapSocialSection")
    }

    @MainActor
    private func refreshAvatarLookup() async {
        let friends = (try? await GoDiveFriendGraphService.listFriendEdges()) ?? []
        let sessionLookup = BuddyFeedAvatarLookup.make(
            currentFirebaseUID: GoDiveFirebaseAuthSession.currentFirebaseUID(),
            currentLocalProfilePhoto: accountSession.currentProfile?.profilePhoto,
            friends: friends
        )
        resolvedAvatarLookup = BuddyFeedAvatarLookup.merging(
            seed: avatarLookup,
            session: sessionLookup
        )
    }

    @MainActor
    private func refreshTalliesFromProjection() async {
        guard let dive = await GoDiveSharedDiveProjectionSync.fetchFriendSharedDive(
            friendUID: ownerUID,
            diveDocumentID: activityID
        ) else { return }
        likeCount = max(0, dive.likeCount)
        commentCount = max(0, dive.commentCount)
    }

    @MainActor
    private func presentCommentsAfterNavigationIfNeeded() async {
        guard BuddyActivityCommentsPresentation.shouldPresentCommentsOnAppear(
            opensCommentsOnAppear: opensCommentsOnAppear,
            alreadyConsumed: didConsumeOpenCommentsOnAppear
        ) else { return }
        // Consume immediately (local + parent) so Map remounts after tab switches do not re-open.
        didConsumeOpenCommentsOnAppear = true
        onOpenCommentsOnAppearConsumed?()
        let delayMs = BuddyActivityCommentsPresentation.openCommentsAfterNavigationDelayMilliseconds
        if delayMs > 0 {
            try? await Task.sleep(for: .milliseconds(delayMs))
        }
        guard !Task.isCancelled else { return }
        presentComments(activatesKeyboard: false)
    }

    @MainActor
    private func presentComments(activatesKeyboard: Bool) {
        commentsSheetTarget = BuddyActivityCommentsSheetTarget(
            ownerUID: ownerUID,
            activityID: activityID,
            seedCommentCount: commentCount,
            activatesKeyboard: activatesKeyboard
        )
    }

    @MainActor
    private func toggleLike() {
        guard !likeWriteInFlight else { return }
        let nextLiked = !isLiked
        let previousLiked = isLiked
        let previousCount = likeCount
        isLiked = nextLiked
        if nextLiked, !previousLiked {
            likeCount += 1
        } else if !nextLiked, previousLiked {
            likeCount = max(0, likeCount - 1)
        }
        likeWriteInFlight = true
        Task { @MainActor in
            defer { likeWriteInFlight = false }
            let succeeded = await GoDiveSharedActivityLikeSync.setLiked(
                ownerUID: ownerUID,
                activityID: activityID,
                liked: nextLiked,
                likerDisplayName: authorDisplayName
            )
            if !succeeded {
                isLiked = previousLiked
                likeCount = previousCount
            }
        }
    }
}
