import SwiftData
import SwiftUI

/// Sheet form to create a user-owned **`MarineLife`** catalog row.
struct FieldGuideMarineLifeAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var onSaved: (String) -> Void

    @State private var form = FieldGuideMarineLifeAddPresentation.FormValues()
    @State private var saveErrorMessage: String?

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
                        accessibilityIdentifier: "FieldGuide.AddSpeciesSheet.Cancel"
                    )
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppGlassProminentDoneButton(
                        action: saveSpecies,
                        accessibilityIdentifier: "FieldGuide.AddSpeciesSheet.Done",
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
        .accessibilityIdentifier("FieldGuide.AddSpeciesSheet.Root")
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )
    }

    private func saveSpecies() {
        guard FieldGuideMarineLifeAddPresentation.canSave(form) else { return }

        let species = FieldGuideMarineLifeAddPresentation.makeMarineLife(from: form)
        modelContext.insert(species)

        do {
            try modelContext.save()
            onSaved(species.uuid)
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
}
