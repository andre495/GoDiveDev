import SwiftData
import SwiftUI

/// Blue modal form to edit a **user-created** Field Guide species.
struct FieldGuideMarineLifeEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let species: MarineLife
    var onSaved: () -> Void = {}

    @State private var form: FieldGuideMarineLifeAddPresentation.FormValues
    @State private var saveErrorMessage: String?

    init(species: MarineLife, onSaved: @escaping () -> Void = {}) {
        self.species = species
        self.onSaved = onSaved
        _form = State(initialValue: FieldGuideMarineLifeAddPresentation.FormValues(from: species))
    }

    var body: some View {
        NavigationStack {
            Form {
                FieldGuideMarineLifeFormContent(form: $form)
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppGlassToolbarCancelButton(
                        action: { dismiss() },
                        accessibilityIdentifier: FieldGuideMarineLifeEditPresentation.cancelAccessibilityIdentifier
                    )
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppGlassProminentDoneButton(
                        action: saveChanges,
                        accessibilityIdentifier: FieldGuideMarineLifeEditPresentation.doneAccessibilityIdentifier,
                        isEnabled: FieldGuideMarineLifeAddPresentation.canSave(form)
                    )
                }
            }
            .alert("Could not save", isPresented: saveErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "Try again.")
            }
        }
        .fieldGuideMarineLifeAddSheetPresentation()
        .accessibilityIdentifier(FieldGuideMarineLifeEditPresentation.rootAccessibilityIdentifier)
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )
    }

    private func saveChanges() {
        do {
            try FieldGuideMarineLifeAddPresentation.applyEdits(
                to: species,
                form: form,
                modelContext: modelContext
            )
            onSaved()
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
}
