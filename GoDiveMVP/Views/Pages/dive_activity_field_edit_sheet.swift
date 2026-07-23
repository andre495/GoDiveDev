import SwiftData
import SwiftUI

/// Sheet editor for a single dive overview field (legacy entry point; prefer section sheet).
struct DiveActivityFieldEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var activity: DiveActivity
    let field: DiveActivityEditableFieldID
    let displayUnits: DiveDisplayUnitSystem

    @State private var draft: DiveActivityFieldEditDraft

    init(activity: DiveActivity, field: DiveActivityEditableFieldID, displayUnits: DiveDisplayUnitSystem) {
        self.activity = activity
        self.field = field
        self.displayUnits = displayUnits
        _draft = State(
            initialValue: DiveActivityFieldEditing.loadDraft(
                for: field,
                activity: activity,
                displayUnits: displayUnits
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DiveActivityFieldEditorRows(
                        activity: activity,
                        field: field,
                        draft: $draft,
                        displayUnits: displayUnits
                    )
                } footer: {
                    if field == .diveSignature {
                        Text("Changes save when you tap Done.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(DiveActivityEditableCatalog.label(for: field))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        saveAndDismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.Colors.tabSelected)
                    .accessibilityIdentifier("DiveFieldEditSheet.\(field.rawValue).Done")
                }
            }
        }
        .diveActivityFieldSheetPresentation()
        .accessibilityIdentifier("DiveFieldEditSheet.\(field.rawValue)")
    }

    private func saveAndDismiss() {
        DiveActivityFieldEditing.applyDraft(
            draft,
            for: field,
            to: activity,
            displayUnits: displayUnits
        )
        try? modelContext.save()
        dismiss()
    }
}
