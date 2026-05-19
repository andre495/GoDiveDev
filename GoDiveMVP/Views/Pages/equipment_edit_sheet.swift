import PhotosUI
import SwiftData
import SwiftUI

/// Sheet form to edit an existing **`EquipmentItem`**.
struct EquipmentEditSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var item: EquipmentItem
    var onSaved: () -> Void = {}

    @State private var form: EquipmentItemFormValues
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var saveErrorMessage: String?

    init(item: EquipmentItem, onSaved: @escaping () -> Void = {}) {
        self.item = item
        self.onSaved = onSaved
        _form = State(initialValue: EquipmentItemFormValues(from: item))
    }

    var body: some View {
        NavigationStack {
            Form {
                EquipmentItemFormContent(form: $form, photoPickerItem: $photoPickerItem)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Edit equipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("EquipmentEditSheet.Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .disabled(!form.canSave)
                    .accessibilityIdentifier("EquipmentEditSheet.Save")
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

    private func saveChanges() {
        guard form.canSave else { return }
        form.apply(to: item)
        do {
            try modelContext.save()
            onSaved()
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
}
