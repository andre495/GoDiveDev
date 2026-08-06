import SwiftUI

/// Compact friend picker shown while composing an `@` mention.
struct GoDiveMentionAutocompleteList: View {
    let friends: [GoDiveFriendGraphService.FriendEdge]
    let onSelect: (GoDiveFriendGraphService.FriendEdge) -> Void

    var body: some View {
        if friends.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(friends) { friend in
                    Button {
                        onSelect(friend)
                    } label: {
                        HStack(spacing: AppTheme.Spacing.sm) {
                            FriendSharedMapOwnerAvatarView(
                                displayName: friend.displayName,
                                photoURL: friend.photoURL,
                                diameter: 28,
                                showsGoDiveUserPin: true
                            )
                            Text(friend.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, AppTheme.Spacing.sm)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("MentionAutocomplete.Friend.\(friend.friendUID)")

                    if friend.id != friends.last?.id {
                        Divider()
                            .padding(.leading, 28 + AppTheme.Spacing.sm)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.Colors.surfaceElevated)
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.Colors.tabUnselected.opacity(0.18), lineWidth: 1)
            )
            .accessibilityIdentifier("MentionAutocomplete.List")
        }
    }
}

/// Tracks UTF-16 caret for mention detection when SwiftUI selection is unavailable.
enum GoDiveMentionCaretTracking: Sendable {
    /// Prefer explicit caret; otherwise assume end of text (typing at end).
    nonisolated static func resolvedUTF16Caret(
        explicit: Int?,
        text: String
    ) -> Int {
        let end = (text as NSString).length
        guard let explicit else { return end }
        return max(0, min(explicit, end))
    }
}
