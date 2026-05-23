import PhotosUI
import SwiftData
import SwiftUI

/// Sheet form to edit an existing **`Certification`**.
struct CertificationEditSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession

    @Bindable var certification: Certification
    var onSaved: () -> Void = {}

    @State private var form: CertificationFormValues
    @State private var frontPhotoPickerItem: PhotosPickerItem?
    @State private var backPhotoPickerItem: PhotosPickerItem?
    @State private var saveErrorMessage: String?

    init(certification: Certification, onSaved: @escaping () -> Void = {}) {
        self.certification = certification
        self.onSaved = onSaved
        _form = State(initialValue: CertificationFormValues(from: certification))
    }

    var body: some View {
        NavigationStack {
            Form {
                CertificationFormContent(
                    form: $form,
                    frontPhotoPickerItem: $frontPhotoPickerItem,
                    backPhotoPickerItem: $backPhotoPickerItem
                )
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Edit certification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("CertificationEditSheet.Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .disabled(!form.canSave)
                    .accessibilityIdentifier("CertificationEditSheet.Save")
                }
            }
            .alert("Could not save", isPresented: saveErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "Try again.")
            }
        }
        .certificationAddSheetPresentation()
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )
    }

    private func saveChanges() {
        guard form.canSave else { return }
        guard (accountSession.currentProfile?.id ?? certification.ownerProfileID) != nil else {
            saveErrorMessage = "Sign in to save changes."
            return
        }

        form.apply(to: certification)
        do {
            try modelContext.save()
            onSaved()
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
}
