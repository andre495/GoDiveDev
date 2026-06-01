import SwiftData
import SwiftUI

/// Edit **`DiveBuddy`** display name and profile photo.
struct DiveBuddyEditSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var buddy: DiveBuddy
    var onSaved: () -> Void = {}

    @State private var nameText = ""
    @State private var saveErrorMessage: String?

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
                        }
                    }
                }

                Section("Name") {
                    TextField("Buddy name", text: $nameText)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("DiveBuddyEditSheet.NameField")
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

    private func saveChanges() {
        let resolved = String(trimmedName.prefix(DiveBuddyCatalog.maxDisplayNameLength))
        guard !resolved.isEmpty else { return }
        buddy.displayName = resolved
        do {
            try modelContext.save()
            onSaved()
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
}
