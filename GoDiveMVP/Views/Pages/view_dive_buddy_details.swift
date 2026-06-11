import Contacts
import SwiftData
import SwiftUI

/// Buddy roster detail — pushed (not a sheet) from **`DiveBuddiesListView`**.
struct ViewDiveBuddyDetails: View {
    @Environment(\.dismiss) private var dismiss
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
    @State private var cachedDiveRows: [DiveLogbookRowDisplayData] = []

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

    private var ownedDiveActivitiesForNumbering: [DiveActivity] {
        guard let ownerProfileID else { return [] }
        return allDiveActivities.filter { $0.ownerProfileID == ownerProfileID }
    }

    private var sharedDiveListRefreshToken: DiveBuddyRosterPresentation.SharedDiveListRefreshToken {
        DiveBuddyRosterPresentation.sharedDiveListRefreshToken(
            buddyID: buddy.id,
            sharedDives: sharedDives,
            unitSystem: diveDisplayUnitSystem,
            useChronologicalNumbers: automaticallyRenumberDives,
            numberingActivities: ownedDiveActivitiesForNumbering
        )
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
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    headerSection

                    divesTogetherSection
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .padding(AppTheme.Spacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        )
        .navigationDestination(for: UUID.self) { diveID in
            if let activity = sharedDives.first(where: { $0.id == diveID }) {
                ViewSingleActivity(activity: activity)
            }
        }
        .task(id: sharedDiveListRefreshToken) {
            refreshCachedDiveRows()
        }
        .hidesBottomTabBarWhenPushed()
        .sheet(isPresented: $showsEditSheet) {
            DiveBuddyEditSheetView(
                buddy: buddy,
                onSaved: {
                    showsEditSheet = false
                },
                onDeleted: {
                    showsEditSheet = false
                    dismiss()
                }
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
        .task(id: buddy.id) {
            refreshLinkedContactOnAppear()
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

    private func refreshCachedDiveRows() {
        cachedDiveRows = DiveBuddyRosterPresentation.sharedDiveRowDisplayData(
            sharedDives: sharedDives,
            unitSystem: diveDisplayUnitSystem,
            useChronologicalNumbers: automaticallyRenumberDives,
            numberingActivities: ownedDiveActivitiesForNumbering
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

    private enum Layout {
        static let avatarDiameter: CGFloat = 120
        static let contactBadgeDiameter: CGFloat = 34
    }

    private var headerSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            buddyAvatarHeader

            Text(buddy.displayName)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)

            Text(DiveBuddyRosterPresentation.sharedDiveCountLabel(sharedDiveCount))
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("DiveBuddyDetails.Header")
    }

    @ViewBuilder
    private var buddyAvatarHeader: some View {
        #if canImport(UIKit)
        ZStack(alignment: .bottomTrailing) {
            ProfileAvatarView(
                profilePhoto: buddy.profilePhoto,
                diameter: Layout.avatarDiameter,
                iconFont: .system(size: 56)
            )

            contactLinkBadge
        }
        #else
        ProfileAvatarView(
            profilePhoto: buddy.profilePhoto,
            diameter: Layout.avatarDiameter,
            iconFont: .system(size: 56)
        )
        #endif
    }

    #if canImport(UIKit)
    private var contactLinkBadge: some View {
        Button {
            presentContactPicker()
        } label: {
            Image(
                systemName: buddy.contactsIdentifier != nil
                    ? "person.fill"
                    : "person.badge.plus"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: Layout.contactBadgeDiameter, height: Layout.contactBadgeDiameter)
            .background(Circle().fill(AppTheme.Colors.tabSelected))
            .overlay {
                Circle()
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            buddy.contactsIdentifier != nil ? "Change linked contact" : "Link contact"
        )
        .accessibilityIdentifier("DiveBuddyDetails.ContactLink")
    }
    #endif

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

    /// Silent refresh when opening a buddy already linked to Contacts.
    private func refreshLinkedContactOnAppear() {
        guard buddy.contactsIdentifier != nil else { return }
        do {
            try DiveBuddyContactLinking.refreshFromContacts(buddy)
            try modelContext.save()
        } catch {
            // Best-effort on load — user can still change contact via the picker.
        }
    }
    #endif

    private var divesTogetherSection: some View {
        ExpandableDetailSection(
            title: "Dives together",
            itemCount: sharedDiveCount,
            scrollsExpandedContent: ExpandableDetailSectionPresentation.buddyDetailScrollsExpandedDiveList,
            keepsExpandedContentMountedAfterFirstReveal:
                ExpandableDetailSectionPresentation.buddyDetailKeepsExpandedContentMounted,
            accessibilityIdentifier: "DiveBuddyDetails.DivesTogether"
        ) {
            Text("No dives tagged with this buddy yet.")
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("DiveBuddyDetails.EmptyDives")
        } content: {
            BuddySharedDiveListRows(rows: cachedDiveRows)
        }
    }
}

/// Logbook rows for buddy **Dives together** — equatable so expand does not rebuild row chrome.
private struct BuddySharedDiveListRows: View, Equatable {
    let rows: [DiveLogbookRowDisplayData]

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ForEach(rows) { row in
                NavigationLink(value: row.id) {
                    LogbookActivityRow(data: row)
                        .equatable()
                }
                .buttonStyle(.plain)
                .navigationLinkIndicatorVisibility(.hidden)
            }
        }
        .accessibilityIdentifier("DiveBuddyDetails.DiveList")
    }
}
