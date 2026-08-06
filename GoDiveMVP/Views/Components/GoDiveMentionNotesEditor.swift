import SwiftUI

/// `TextEditor` with `@` friend autocomplete (mutual friends). Assumes typing at end of text.
struct GoDiveMentionNotesEditor: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var friends: [GoDiveFriendGraphService.FriendEdge]

    private var activeMention: GoDiveMentionPresentation.ActiveMention? {
        GoDiveMentionPresentation.activeMention(
            in: text,
            utf16Caret: (text as NSString).length,
            friends: friends
        )
    }

    private var suggestions: [GoDiveFriendGraphService.FriendEdge] {
        guard let active = activeMention else { return [] }
        return GoDiveMentionPresentation.matchingFriends(
            query: active.query,
            friends: friends
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            if !suggestions.isEmpty {
                GoDiveMentionAutocompleteList(friends: suggestions) { friend in
                    insert(friend)
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
            }

            TextEditor(text: $text)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.visible)
                .focused(isFocused)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func insert(_ friend: GoDiveFriendGraphService.FriendEdge) {
        guard let active = activeMention else { return }
        let insertion = GoDiveMentionPresentation.insertMention(
            displayName: friend.displayName,
            into: text,
            active: active
        )
        text = insertion.text
    }
}
