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
    @State private var cardPhotoPreview: CertificationCardPhotoPreviewSelection?

    var body: some View {
        NavigationStack {
            Form {
                CertificationFormContent(
                    form: $form,
                    frontPhotoPickerItem: $frontPhotoPickerItem,
                    backPhotoPickerItem: $backPhotoPickerItem,
                    cardPhotoPreview: $cardPhotoPreview,
                    clearsListRowBackgrounds: true
                )
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppGlassToolbarCancelButton(
                        action: { dismiss() },
                        accessibilityIdentifier: CertificationPresentation.addSheetCancelAccessibilityIdentifier
                    )
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppGlassProminentDoneButton(
                        action: saveCertification,
                        accessibilityIdentifier: CertificationPresentation.addSheetDoneAccessibilityIdentifier,
                        isEnabled: form.canSave
                    )
                }
            }
            .alert("Could not save", isPresented: saveErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "Try again.")
            }
        }
        .certificationCardPhotoPreviewCover($cardPhotoPreview)
        .diveActivityOverviewPanelModalSheetPresentation()
        .accessibilityIdentifier("CertificationAddSheet.Root")
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
