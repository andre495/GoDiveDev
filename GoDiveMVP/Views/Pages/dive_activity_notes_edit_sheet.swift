import SwiftData
import SwiftUI

/// Dedicated map-tab notes editor using the same blue panel styling as the overview detent.
struct DiveActivityNotesEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var activity: DiveActivity

    @State private var draftText: String
    @FocusState private var isNotesFieldFocused: Bool

    private enum NotesPresentation {
        static let maxCharacterCount = DiveNotesValidation.maxCharacterCount
    }

    init(activity: DiveActivity) {
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
        }
        .diveActivityOverviewPanelModalSheetPresentation()
        .accessibilityIdentifier("DiveNotesEditSheet.Root")
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
