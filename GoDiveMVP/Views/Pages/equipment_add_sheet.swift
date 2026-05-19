import PhotosUI
import SwiftData
import SwiftUI

/// Sheet form to create a new **`EquipmentItem`** for the signed-in profile.
struct EquipmentAddSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession

    var onSaved: () -> Void = {}

    @State private var form = EquipmentItemFormValues()
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var saveErrorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                EquipmentItemFormContent(form: $form, photoPickerItem: $photoPickerItem)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("New equipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("EquipmentAddSheet.Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEquipment()
                    }
                    .fontWeight(.semibold)
                    .disabled(!form.canSave)
                    .accessibilityIdentifier("EquipmentAddSheet.Save")
                }
            }
            .alert("Could not save", isPresented: saveErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "Try again.")
            }
        }
        .equipmentAddSheetPresentation()
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )
    }

    private func saveEquipment() {
        guard form.canSave else { return }
        guard let profile = accountSession.currentProfile else {
            saveErrorMessage = "Sign in to save equipment."
            return
        }

        let item = form.makeEquipmentItem()
        EquipmentItemOwnership.assignOwner(profile, to: item)
        modelContext.insert(item)

        do {
            try modelContext.save()
            onSaved()
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
}

#Preview {
    EquipmentAddSheetView()
        .environment(AccountSession.shared)
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
