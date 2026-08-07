import Contacts
import SwiftData
import SwiftUI

/// Edit **`DiveBuddy`** display name, profile photo, and Contacts link.
struct DiveBuddyEditSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession

    @Bindable var buddy: DiveBuddy
    var onSaved: () -> Void = {}
    var onDeleted: () -> Void = {}

    @State private var nameText = ""
    @State private var saveErrorMessage: String?
    @State private var deleteErrorMessage: String?
    @State private var showsDeleteConfirmation = false
    @State private var showsContactPicker = false
    @State private var contactsAccessError: String?
    @State private var contactLinkError: String?

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

                #if canImport(UIKit)
                Section(DiveBuddyEditContactPresentation.sectionTitle) {
                    Button {
                        presentContactPicker()
                    } label: {
                        Label(
                            DiveBuddyEditContactPresentation.linkButtonTitle(
                                isLinked: buddy.contactsIdentifier != nil
                            ),
                            systemImage: buddy.contactsIdentifier != nil
                                ? "person.crop.circle"
                                : "person.crop.circle.badge.plus"
                        )
                    }
                    .accessibilityIdentifier(
                        DiveBuddyEditContactPresentation.linkAccessibilityIdentifier
                    )

                    if buddy.contactsIdentifier != nil {
                        Button(DiveBuddyEditContactPresentation.disconnectButtonTitle, role: .destructive) {
                            disconnectContact()
                        }
                        .accessibilityIdentifier(
                            DiveBuddyEditContactPresentation.disconnectAccessibilityIdentifier
                        )
                    }
                }
                #endif

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
            .alert("Contacts", isPresented: contactsAccessAlertBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(contactsAccessError ?? "")
            }
            .alert("Could not link contact", isPresented: contactLinkAlertBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(contactLinkError ?? "")
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
            #if canImport(UIKit)
            .sheet(isPresented: $showsContactPicker) {
                ContactPickerView(
                    onPick: { contact in
                        showsContactPicker = false
                        linkContact(contact)
                    },
                    onCancel: {
                        showsContactPicker = false
                    }
                )
            }
            #endif
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

    private var contactsAccessAlertBinding: Binding<Bool> {
        Binding(
            get: { contactsAccessError != nil },
            set: { if !$0 { contactsAccessError = nil } }
        )
    }

    private var contactLinkAlertBinding: Binding<Bool> {
        Binding(
            get: { contactLinkError != nil },
            set: { if !$0 { contactLinkError = nil } }
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

    #if canImport(UIKit)
    private func presentContactPicker() {
        ContactsPickerAccess.presentIfAuthorized(
            onAuthorized: { showsContactPicker = true },
            onError: { contactsAccessError = $0 }
        )
    }

    private func linkContact(_ contact: CNContact) {
        do {
            try DiveBuddyContactLinking.apply(
                contact: contact,
                to: buddy,
                owner: accountSession.currentProfile,
                modelContext: modelContext
            )
            try modelContext.save()
            nameText = buddy.displayName
            DiveBuddyRosterChangeNotification.post()
        } catch {
            contactLinkError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func disconnectContact() {
        DiveBuddyContactLinking.disconnect(buddy)
        do {
            try modelContext.save()
            DiveBuddyRosterChangeNotification.post()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
    #endif
}
