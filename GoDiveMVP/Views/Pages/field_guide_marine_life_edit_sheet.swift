import SwiftData
import SwiftUI

/// Blue modal form to edit a **user-created** Field Guide species.
struct FieldGuideMarineLifeEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private enum BoundSpecies {
        case catalog(MarineLife)
        case user(UserMarineLife)
    }

    private let boundSpecies: BoundSpecies
    var onSaved: () -> Void = {}

    @State private var form: FieldGuideMarineLifeAddPresentation.FormValues
    @State private var saveErrorMessage: String?

    init(species: MarineLife, onSaved: @escaping () -> Void = {}) {
        self.boundSpecies = .catalog(species)
        self.onSaved = onSaved
        _form = State(initialValue: FieldGuideMarineLifeAddPresentation.FormValues(from: species))
    }

    init(species: UserMarineLife, onSaved: @escaping () -> Void = {}) {
        self.boundSpecies = .user(species)
        self.onSaved = onSaved
        _form = State(initialValue: FieldGuideMarineLifeAddPresentation.FormValues(from: species))
    }

    init(species: FieldGuideSpeciesBinding, onSaved: @escaping () -> Void = {}) {
        switch species {
        case .catalog(let catalog):
            self.boundSpecies = .catalog(catalog)
            _form = State(initialValue: FieldGuideMarineLifeAddPresentation.FormValues(from: catalog))
        case .user(let user):
            self.boundSpecies = .user(user)
            _form = State(initialValue: FieldGuideMarineLifeAddPresentation.FormValues(from: user))
        }
        self.onSaved = onSaved
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
            switch boundSpecies {
            case .catalog(let species):
                try FieldGuideMarineLifeAddPresentation.applyEdits(
                    to: species,
                    form: form,
                    modelContext: modelContext
                )
            case .user(let species):
                try FieldGuideMarineLifeAddPresentation.applyEdits(
                    to: species,
                    form: form,
                    modelContext: modelContext
                )
            }
            onSaved()
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
}
