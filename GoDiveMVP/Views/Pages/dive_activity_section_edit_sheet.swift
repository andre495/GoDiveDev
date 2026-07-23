import SwiftData
import SwiftUI

/// Sheet editor for all editable fields in one dive overview section.
struct DiveActivitySectionEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var activity: DiveActivity
    let section: DiveActivityEditableCatalog.Section
    let displayUnits: DiveDisplayUnitSystem

    @State private var drafts: [DiveActivityEditableFieldID: DiveActivityFieldEditDraft]

    private var editableFields: [DiveActivityEditableFieldID] {
        DiveActivityEditableCatalog.editableFields(in: section, for: activity)
    }

    init(
        activity: DiveActivity,
        section: DiveActivityEditableCatalog.Section,
        displayUnits: DiveDisplayUnitSystem
    ) {
        self.activity = activity
        self.section = section
        self.displayUnits = displayUnits
        var loaded: [DiveActivityEditableFieldID: DiveActivityFieldEditDraft] = [:]
        for field in DiveActivityEditableCatalog.editableFields(in: section, for: activity) {
            loaded[field] = DiveActivityFieldEditing.loadDraft(
                for: field,
                activity: activity,
                displayUnits: displayUnits
            )
        }
        _drafts = State(initialValue: loaded)
    }

    private var usesOverviewPanelStyle: Bool {
        DiveActivityEditableCatalog.usesOverviewPanelModalEditor(section: section)
    }

    var body: some View {
        if usesOverviewPanelStyle {
            overviewPanelStyleBody
        } else {
            standardBody
        }
    }

    private var overviewPanelStyleBody: some View {
        NavigationStack {
            Form {
                ForEach(editableFields, id: \.self) { field in
                    Section {
                        DiveActivityFieldEditorRows(
                            activity: activity,
                            field: field,
                            draft: draftBinding(for: field),
                            displayUnits: displayUnits
                        )
                        .listRowBackground(Color.clear)
                    } header: {
                        if showsFieldHeader(for: field) {
                            Text(DiveActivityEditableCatalog.label(for: field))
                        }
                    } footer: {
                        if field == .diveSignature {
                            Text("Changes save when you tap Done.")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppGlassToolbarCancelButton(
                        action: { dismiss() },
                        accessibilityIdentifier: "DiveSectionEditSheet.\(section.id).Cancel"
                    )
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppGlassProminentDoneButton(
                        action: saveAndDismiss,
                        accessibilityIdentifier: "DiveSectionEditSheet.\(section.id).Done"
                    )
                }
            }
        }
        .diveActivityOverviewPanelModalSheetPresentation()
        .accessibilityIdentifier("DiveSectionEditSheet.\(section.id)")
    }

    private var standardBody: some View {
        NavigationStack {
            Form {
                ForEach(editableFields, id: \.self) { field in
                    Section {
                        DiveActivityFieldEditorRows(
                            activity: activity,
                            field: field,
                            draft: draftBinding(for: field),
                            displayUnits: displayUnits
                        )
                    } header: {
                        if showsFieldHeader(for: field) {
                            Text(DiveActivityEditableCatalog.label(for: field))
                        }
                    } footer: {
                        if field == .diveSignature {
                            Text("Changes save when you tap Done.")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(section.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        saveAndDismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.Colors.tabSelected)
                    .accessibilityIdentifier("DiveSectionEditSheet.\(section.id).Done")
                }
            }
        }
        .diveActivityFieldSheetPresentation()
        .accessibilityIdentifier("DiveSectionEditSheet.\(section.id)")
    }

    private func showsFieldHeader(for field: DiveActivityEditableFieldID) -> Bool {
        field != .notes
    }

    private func draftBinding(for field: DiveActivityEditableFieldID) -> Binding<DiveActivityFieldEditDraft> {
        Binding(
            get: { drafts[field] ?? DiveActivityFieldEditDraft() },
            set: { drafts[field] = $0 }
        )
    }

    private func saveAndDismiss() {
        for field in editableFields {
            guard let draft = drafts[field] else { continue }
            DiveActivityFieldEditing.applyDraft(
                draft,
                for: field,
                to: activity,
                displayUnits: displayUnits
            )
        }
        try? modelContext.save()
        dismiss()
    }
}
