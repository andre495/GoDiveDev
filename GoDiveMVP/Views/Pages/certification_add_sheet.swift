import PhotosUI
import SwiftData
import SwiftUI

/// Sheet form to create a new **`Certification`** for the signed-in profile.
struct CertificationAddSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession

    var onSaved: () -> Void = {}

    @State private var form = CertificationFormValues()
    @State private var frontPhotoPickerItem: PhotosPickerItem?
    @State private var backPhotoPickerItem: PhotosPickerItem?
    @State private var saveErrorMessage: String?

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
            .navigationTitle("New certification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("CertificationAddSheet.Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCertification()
                    }
                    .fontWeight(.semibold)
                    .disabled(!form.canSave)
                    .accessibilityIdentifier("CertificationAddSheet.Save")
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

    private func saveCertification() {
        guard form.canSave else { return }
        guard let profile = accountSession.currentProfile else {
            saveErrorMessage = "Sign in to save a certification."
            return
        }

        let certification = form.makeCertification()
        CertificationOwnership.assignOwner(profile, to: certification)
        modelContext.insert(certification)

        do {
            try modelContext.save()
            if form.isPrimaryCert {
                try CertificationOwnership.setAsPrimary(
                    certification,
                    ownerProfileID: profile.id,
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

#Preview {
    CertificationAddSheetView()
        .environment(AccountSession.shared)
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
