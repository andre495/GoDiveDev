import SwiftData
import SwiftUI

/// Dedicated map-tab notes editor using the same blue panel styling as the overview detent.
struct DiveActivityNotesEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession

    @Bindable var activity: DiveActivity

    @State private var draftText: String
    @State private var friends: [GoDiveFriendGraphService.FriendEdge] = []
    @FocusState private var isNotesFieldFocused: Bool

    init(activity: DiveActivity) {
        self.activity = activity
        _draftText = State(
            initialValue: DiveNotesValidation.draftNotes(activity.notes ?? "")
        )
    }

    var body: some View {
        NavigationStack {
            GoDiveMentionNotesEditor(
                text: draftBinding,
                isFocused: $isNotesFieldFocused,
                friends: friends
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppGlassToolbarCancelButton(
                        action: {
                            isNotesFieldFocused = false
                            dismiss()
                        },
                        accessibilityIdentifier: "DiveNotesEditSheet.Cancel"
                    )
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppGlassProminentDoneButton(
                        action: saveAndDismiss,
                        accessibilityIdentifier: "DiveNotesEditSheet.Done"
                    )
                }
            }
            .onAppear {
                isNotesFieldFocused = true
            }
            .task {
                friends = (try? await GoDiveFriendGraphService.listFriendEdges()) ?? []
            }
        }
        .diveActivityOverviewPanelModalSheetPresentation()
        .accessibilityIdentifier("DiveNotesEditSheet.Root")
    }

    private var draftBinding: Binding<String> {
        Binding(
            get: { draftText },
            set: { newValue in
                draftText = DiveNotesValidation.draftNotes(newValue)
            }
        )
    }

    private func saveAndDismiss() {
        isNotesFieldFocused = false
        let notes = GoDiveInputSanitization.sanitizedNotes(draftText)
        activity.notes = notes
        GoDiveNotesMentionTagging.tagMentionedFriends(
            inNotes: notes ?? "",
            friends: friends,
            on: activity,
            owner: accountSession.currentProfile,
            modelContext: modelContext
        )
        try? modelContext.save()
        dismiss()
    }
}
