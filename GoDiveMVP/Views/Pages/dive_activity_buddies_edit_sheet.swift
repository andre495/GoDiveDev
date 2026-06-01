import Contacts
import SwiftData
import SwiftUI

/// Add, rename, or remove buddy tags on a dive.
struct DiveActivityBuddiesEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession

    @Bindable var activity: DiveActivity

    @State private var newBuddyName = ""
    @State private var showsContactPicker = false
    @State private var contactsAccessError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Buddy name", text: $newBuddyName)
                            .textInputAutocapitalization(.words)
                        Button("Add") {
                            addManualBuddy()
                        }
                        .disabled(newBuddyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    #if canImport(UIKit)
                    Button {
                        presentContactPicker()
                    } label: {
                        Label("Add from Contacts", systemImage: "person.crop.circle.badge.plus")
                    }
                    .accessibilityIdentifier("DiveBuddiesEditSheet.AddFromContacts")
                    #endif
                } header: {
                    Text("Add buddy")
                }

                Section("On this dive") {
                    if activity.buddies.isEmpty {
                        Text("No buddies yet.")
                            .foregroundStyle(AppTheme.Colors.tabUnselected)
                    } else {
                        ForEach(activity.buddies, id: \.id) { tag in
                            buddyRow(tag)
                        }
                        .onDelete(perform: deleteBuddies)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Buddies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .diveActivityFieldSheetPresentation()
        .accessibilityIdentifier("DiveBuddiesEditSheet.Root")
        #if canImport(UIKit)
        .sheet(isPresented: $showsContactPicker) {
            ContactPickerView(
                onPick: { contact in
                    showsContactPicker = false
                    addBuddy(from: contact)
                },
                onCancel: {
                    showsContactPicker = false
                }
            )
        }
        #endif
        .alert("Contacts", isPresented: contactsErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(contactsAccessError ?? "")
        }
    }

    @ViewBuilder
    private func buddyRow(_ tag: DiveBuddyTag) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            if let buddy = tag.buddy {
                ProfileAvatarView(
                    profilePhoto: buddy.profilePhoto,
                    diameter: 40,
                    iconFont: .body
                )
                TextField("Name", text: buddyNameBinding(buddy))
                    .textInputAutocapitalization(.words)
            } else {
                TextField("Name", text: .constant(tag.displayName))
                    .textInputAutocapitalization(.words)
                    .disabled(true)
            }
        }
    }

    private var contactsErrorBinding: Binding<Bool> {
        Binding(
            get: { contactsAccessError != nil },
            set: { if !$0 { contactsAccessError = nil } }
        )
    }

    private func buddyNameBinding(_ buddy: DiveBuddy) -> Binding<String> {
        Binding(
            get: { buddy.displayName },
            set: { buddy.displayName = String($0.prefix(DiveBuddyCatalog.maxDisplayNameLength)) }
        )
    }

    private func addManualBuddy() {
        let trimmed = newBuddyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        _ = DiveBuddyActivityAssociation.tagNewBuddy(
            displayName: trimmed,
            owner: accountSession.currentProfile,
            on: activity,
            modelContext: modelContext
        )
        newBuddyName = ""
    }

    #if canImport(UIKit)
    private func presentContactPicker() {
        let store = CNContactStore()
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized, .limited:
            showsContactPicker = true
        case .notDetermined:
            store.requestAccess(for: .contacts) { granted, error in
                Task { @MainActor in
                    if let error {
                        contactsAccessError = error.localizedDescription
                        return
                    }
                    if granted {
                        showsContactPicker = true
                    } else {
                        contactsAccessError = "Allow Contacts access in Settings to pick a dive buddy."
                    }
                }
            }
        case .denied, .restricted:
            contactsAccessError = "Allow Contacts access in Settings to pick a dive buddy."
        @unknown default:
            contactsAccessError = "Contacts are not available."
        }
    }

    private func addBuddy(from contact: CNContact) {
        let name = DiveBuddyContactImport.displayName(from: contact)
        let photo = DiveBuddyContactImport.profilePhotoData(from: contact)
        let identifier = DiveBuddyContactImport.contactsIdentifier(from: contact)

        if let owner = accountSession.currentProfile,
           let existing = try? DiveBuddyCatalog.findByContactsIdentifier(
               identifier,
               ownerProfileID: owner.id,
               modelContext: modelContext
           ),
           DiveBuddyActivityAssociation.isBuddyTagged(buddyID: existing.id, on: activity)
        {
            return
        }

        _ = DiveBuddyActivityAssociation.tagNewBuddy(
            displayName: name,
            profilePhoto: photo,
            contactsIdentifier: identifier,
            owner: accountSession.currentProfile,
            on: activity,
            modelContext: modelContext
        )
    }
    #endif

    private func deleteBuddies(at offsets: IndexSet) {
        let sorted = activity.buddies
        for index in offsets {
            let tag = sorted[index]
            DiveBuddyActivityAssociation.removeTag(tag, from: activity, modelContext: modelContext)
        }
        activity.buddies.remove(atOffsets: offsets)
    }
}
