import SwiftData
import SwiftUI

/// Dedicated map-tab notes editor for snorkels — same blue panel chrome as dive notes.
struct SnorkelActivityNotesEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var activity: SnorkelActivity

    @State private var draftText: String
    @FocusState private var isNotesFieldFocused: Bool

    private enum NotesPresentation {
        static let maxCharacterCount = DiveNotesValidation.maxCharacterCount
    }

    init(activity: SnorkelActivity) {
        self.activity = activity
        _draftText = State(
            initialValue: String((activity.notes ?? "").prefix(NotesPresentation.maxCharacterCount))
        )
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: draftBinding)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.visible)
                .focused($isNotesFieldFocused)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        AppGlassToolbarCancelButton(
                            action: {
                                isNotesFieldFocused = false
                                dismiss()
                            },
                            accessibilityIdentifier: "SnorkelNotesEditSheet.Cancel"
                        )
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        AppGlassProminentDoneButton(
                            action: saveAndDismiss,
                            accessibilityIdentifier: "SnorkelNotesEditSheet.Done"
                        )
                    }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            isNotesFieldFocused = false
                        }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.tabSelected)
                    }
                }
                .onAppear {
                    isNotesFieldFocused = true
                }
        }
        .diveActivityOverviewPanelModalSheetPresentation()
        .accessibilityIdentifier("SnorkelNotesEditSheet.Root")
    }

    private var draftBinding: Binding<String> {
        Binding(
            get: { draftText },
            set: { newValue in
                draftText = DiveNotesValidation.cappedNotes(newValue)
            }
        )
    }

    private func saveAndDismiss() {
        isNotesFieldFocused = false
        activity.notes = GoDiveInputSanitization.sanitizedNotes(draftText)
        try? modelContext.save()
        dismiss()
    }
}
