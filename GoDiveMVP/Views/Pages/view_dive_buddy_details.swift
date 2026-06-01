import Contacts
import SwiftData
import SwiftUI

/// Buddy roster detail — pushed (not a sheet) from **`DiveBuddiesListView`**.
struct ViewDiveBuddyDetails: View {
    @Environment(AccountSession.self) private var accountSession
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @Environment(\.modelContext) private var modelContext

    @AppStorage(AppUserSettings.automaticallyRenumberDivesKey) private var automaticallyRenumberDives = true

    @Bindable var buddy: DiveBuddy

    @Query(sort: [SortDescriptor(\DiveActivity.startTime, order: .reverse)])
    private var allDiveActivities: [DiveActivity]

    @State private var showsEditSheet = false
    @State private var showsContactPicker = false
    @State private var contactsAccessError: String?
    @State private var contactLinkError: String?

    private var ownerProfileID: UUID? {
        accountSession.currentProfile?.id
    }

    private var sharedDives: [DiveActivity] {
        guard let ownerProfileID else { return [] }
        return DiveBuddyRosterPresentation.sharedDiveActivities(for: buddy, ownerProfileID: ownerProfileID)
    }

    private var sharedDiveCount: Int {
        sharedDives.count
    }

    private var diveRows: [DiveLogbookRowDisplayData] {
        DiveLogbookDisplay.rowData(
            activities: sharedDives,
            unitSystem: diveDisplayUnitSystem,
            duplicateIds: [],
            useChronologicalNumbers: automaticallyRenumberDives,
            numberingActivities: ownedDiveActivitiesForNumbering
        )
    }

    private var ownedDiveActivitiesForNumbering: [DiveActivity] {
        guard let ownerProfileID else { return [] }
        return allDiveActivities.filter { $0.ownerProfileID == ownerProfileID }
    }

    var body: some View {
        AppPage(
            title: buddy.displayName,
            showsBackButton: true,
            trailingContent: {
                Button("Edit") {
                    showsEditSheet = true
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabSelected)
                .accessibilityIdentifier("DiveBuddyDetails.Edit")
            },
            content: {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                        headerSection
                        contactsSection
                        divesTogetherSection
                    }
                    .padding(AppTheme.Spacing.md)
                }
            }
        )
        .hidesBottomTabBarWhenPushed()
        .sheet(isPresented: $showsEditSheet) {
            DiveBuddyEditSheetView(buddy: buddy) {
                showsEditSheet = false
            }
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
        .accessibilityIdentifier("DiveBuddyDetails.Root")
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

    private var headerSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ProfileAvatarView(
                profilePhoto: buddy.profilePhoto,
                diameter: 120,
                iconFont: .system(size: 56)
            )

            Text(buddy.displayName)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Text(DiveBuddyRosterPresentation.sharedDiveCountLabel(sharedDiveCount))
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("DiveBuddyDetails.Header")
    }

    @ViewBuilder
    private var contactsSection: some View {
        #if canImport(UIKit)
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            if buddy.contactsIdentifier != nil {
                Label("Linked to Contacts", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                Button("Refresh name and photo") {
                    refreshLinkedContact()
                }
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.Colors.tabSelected)

                Button("Change contact") {
                    presentContactPicker()
                }
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.Colors.tabSelected)

                Button("Disconnect contact", role: .destructive) {
                    disconnectLinkedContact()
                }
                .font(.body)
            } else {
                Button {
                    presentContactPicker()
                } label: {
                    Label("Connect to Contact", systemImage: "person.crop.circle.badge.plus")
                        .font(.body.weight(.medium))
                }
                .foregroundStyle(AppTheme.Colors.tabSelected)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("DiveBuddyDetails.Contacts")
        #endif
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
        } catch {
            contactLinkError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func refreshLinkedContact() {
        do {
            try DiveBuddyContactLinking.refreshFromContacts(buddy)
            try modelContext.save()
        } catch {
            contactLinkError = error.localizedDescription
        }
    }

    private func disconnectLinkedContact() {
        DiveBuddyContactLinking.disconnect(buddy)
        try? modelContext.save()
    }
    #endif

    @ViewBuilder
    private var divesTogetherSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Dives together")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            if diveRows.isEmpty {
                Text("No dives tagged with this buddy yet.")
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("DiveBuddyDetails.EmptyDives")
            } else {
                VStack(spacing: AppTheme.Spacing.md) {
                    ForEach(diveRows) { row in
                        if let activity = sharedDives.first(where: { $0.id == row.id }) {
                            NavigationLink {
                                ViewSingleActivity(activity: activity)
                            } label: {
                                LogbookActivityRow(data: row)
                            }
                            .buttonStyle(.plain)
                            .navigationLinkIndicatorVisibility(.hidden)
                        }
                    }
                }
                .accessibilityIdentifier("DiveBuddyDetails.DiveList")
            }
        }
    }
}
