import Contacts
import SwiftData
import SwiftUI

/// Create a roster buddy, optionally tagging them on a dive.
struct DiveActivityAddBuddySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession

    private var activity: DiveActivity?
    private let deferActivityTagging: Bool
    private let onBuddyCreated: ((DiveBuddy) -> Void)?

    @State private var newBuddyName = ""
    @State private var showsContactPicker = false
    @State private var contactsAccessError: String?
    @State private var addBuddyError: String?

    init(
        activity: DiveActivity,
        deferActivityTagging: Bool = false,
        onBuddyCreated: ((DiveBuddy) -> Void)? = nil
    ) {
        self.activity = activity
        self.deferActivityTagging = deferActivityTagging
        self.onBuddyCreated = onBuddyCreated
    }

    /// Roster-only create from **Profile → Dive Buddies** **+**.
    init(onBuddyCreated: ((DiveBuddy) -> Void)? = nil) {
        self.activity = nil
        self.deferActivityTagging = false
        self.onBuddyCreated = onBuddyCreated
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Buddy name", text: $newBuddyName)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("DiveActivityAddBuddySheet.NameField")
                } header: {
                    Text("Name")
                }

                #if canImport(UIKit)
                Section {
                    Button {
                        presentContactPicker()
                    } label: {
                        Label("Connect to Contact", systemImage: "person.crop.circle.badge.plus")
                    }
                    .accessibilityIdentifier("DiveActivityAddBuddySheet.ConnectContact")
                }
                #endif
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("New buddy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addManualBuddy()
                    }
                    .fontWeight(.semibold)
                    .disabled(newBuddyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("DiveActivityAddBuddySheet.Add")
                }
            }
        }
        .diveActivityFieldSheetPresentation()
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
        .alert("Contacts", isPresented: contactsAccessAlertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(contactsAccessError ?? "")
        }
        .alert("Could not add buddy", isPresented: addBuddyErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(addBuddyError ?? "")
        }
        .accessibilityIdentifier("DiveActivityAddBuddySheet.Root")
    }

    private var contactsAccessAlertBinding: Binding<Bool> {
        Binding(
            get: { contactsAccessError != nil },
            set: { if !$0 { contactsAccessError = nil } }
        )
    }

    private var addBuddyErrorBinding: Binding<Bool> {
        Binding(
            get: { addBuddyError != nil },
            set: { if !$0 { addBuddyError = nil } }
        )
    }

    private func addManualBuddy() {
        let trimmed = newBuddyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let activity, !deferActivityTagging {
            guard
                DiveBuddyActivityAssociation.tagNewBuddy(
                    displayName: trimmed,
                    owner: accountSession.currentProfile,
                    on: activity,
                    modelContext: modelContext
                ) != nil
            else {
                addBuddyError = "That name matches your profile and cannot be added as a dive buddy."
                return
            }
            try? modelContext.save()
            dismiss()
            return
        }

        guard
            let buddy = DiveBuddyRosterCreation.addBuddy(
                displayName: trimmed,
                owner: accountSession.currentProfile,
                modelContext: modelContext
            )
        else {
            addBuddyError = "That name matches your profile and cannot be added as a dive buddy."
            return
        }

        try? modelContext.save()
        onBuddyCreated?(buddy)
        dismiss()
    }

    #if canImport(UIKit)
    private func presentContactPicker() {
        ContactsPickerAccess.presentIfAuthorized(
            onAuthorized: { showsContactPicker = true },
            onError: { contactsAccessError = $0 }
        )
    }

    private func addBuddy(from contact: CNContact) {
        let name = DiveBuddyContactImport.displayName(from: contact)
        let photo = DiveBuddyContactImport.profilePhotoData(from: contact)
        let identifier = DiveBuddyContactImport.contactsIdentifier(from: contact)

        if let owner = accountSession.currentProfile,
           DiveBuddyCatalog.shouldExcludeBuddyName(name, owner: owner)
        {
            addBuddyError = "That contact matches your profile and cannot be added as a dive buddy."
            return
        }

        if let owner = accountSession.currentProfile,
           let existing = try? DiveBuddyCatalog.findByContactsIdentifier(
               identifier,
               ownerProfileID: owner.id,
               modelContext: modelContext
           )
        {
            if let activity, !deferActivityTagging {
                if DiveBuddyActivityAssociation.isBuddyTagged(buddyID: existing.id, on: activity) {
                    dismiss()
                    return
                }
                DiveBuddyActivityAssociation.tagBuddy(existing, on: activity, modelContext: modelContext)
                try? modelContext.save()
                dismiss()
                return
            }

            try? modelContext.save()
            onBuddyCreated?(existing)
            dismiss()
            return
        }

        if let activity, !deferActivityTagging {
            guard
                DiveBuddyActivityAssociation.tagNewBuddy(
                    displayName: name,
                    profilePhoto: photo,
                    contactsIdentifier: identifier,
                    owner: accountSession.currentProfile,
                    on: activity,
                    modelContext: modelContext
                ) != nil
            else {
                addBuddyError = "Could not add that contact as a buddy."
                return
            }
            try? modelContext.save()
            dismiss()
            return
        }

        guard
            let buddy = DiveBuddyRosterCreation.addBuddy(
                displayName: name,
                profilePhoto: photo,
                contactsIdentifier: identifier,
                owner: accountSession.currentProfile,
                modelContext: modelContext
            )
        else {
            addBuddyError = "Could not add that contact as a buddy."
            return
        }

        try? modelContext.save()
        onBuddyCreated?(buddy)
        dismiss()
    }
    #endif
}
