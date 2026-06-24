import SwiftData
import SwiftUI

/// Edit **`DiveBuddy`** display name and profile photo.
struct DiveBuddyEditSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var buddy: DiveBuddy
    var onSaved: () -> Void = {}
    var onDeleted: () -> Void = {}

    @State private var nameText = ""
    @State private var saveErrorMessage: String?
    @State private var deleteErrorMessage: String?
    @State private var showsDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer(minLength: 0)
                        DiveBuddyAvatarEditor(diameter: 120, buddy: buddy)
                        Spacer(minLength: 0)
                    }
                    .listRowBackground(Color.clear)

                    if buddy.profilePhoto != nil {
                        Button("Remove photo", role: .destructive) {
                            buddy.profilePhoto = nil
                            do {
                                try modelContext.save()
                                DiveBuddyRosterChangeNotification.post()
                            } catch {
                                saveErrorMessage = error.localizedDescription
                            }
                        }
                    }
                }

                Section("Name") {
                    TextField("Buddy name", text: $nameText)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("DiveBuddyEditSheet.NameField")
                }

                Section {
                    Button("Delete buddy", role: .destructive) {
                        showsDeleteConfirmation = true
                    }
                    .accessibilityIdentifier("DiveBuddyEditSheet.Delete")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Edit buddy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("DiveBuddyEditSheet.Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .disabled(trimmedName.isEmpty)
                    .accessibilityIdentifier("DiveBuddyEditSheet.Save")
                }
            }
            .alert("Could not save", isPresented: saveErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "Try again.")
            }
            .alert("Could not delete buddy", isPresented: deleteErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteErrorMessage ?? "Try again.")
            }
            .confirmationDialog(
                "Delete buddy?",
                isPresented: $showsDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete buddy", role: .destructive) {
                    deleteBuddy()
                }
            } message: {
                Text(
                    "This removes \(buddy.displayName) from your roster and untags them on all dives. This cannot be undone."
                )
            }
        }
        .equipmentAddSheetPresentation()
        .onAppear {
            nameText = buddy.displayName
        }
        .accessibilityIdentifier("DiveBuddyEditSheet.Root")
    }

    private var trimmedName: String {
        nameText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )
    }

    private var deleteErrorBinding: Binding<Bool> {
        Binding(
            get: { deleteErrorMessage != nil },
            set: { if !$0 { deleteErrorMessage = nil } }
        )
    }

    private func saveChanges() {
        let resolved = String(trimmedName.prefix(DiveBuddyCatalog.maxDisplayNameLength))
        guard !resolved.isEmpty else { return }
        buddy.displayName = resolved
        do {
            try modelContext.save()
            DiveBuddyRosterChangeNotification.post()
            onSaved()
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }

    private func deleteBuddy() {
        do {
            try DiveBuddyDeletion.deletePermanently(buddy, modelContext: modelContext)
            DiveBuddyRosterChangeNotification.post()
            dismiss()
            onDeleted()
        } catch {
            deleteErrorMessage = error.localizedDescription
        }
    }
}
