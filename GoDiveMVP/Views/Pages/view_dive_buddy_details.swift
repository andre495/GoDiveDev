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

    @Query private var buddyDiveTags: [DiveBuddyTag]

    @Query private var buddyMediaTags: [DiveMediaBuddyTag]

    @State private var showsEditSheet = false
    @State private var showsContactPicker = false
    @State private var contactsAccessError: String?
    @State private var contactLinkError: String?
    @State private var showsSecondarySections = false
    @State private var cachedSharedDives: [DiveActivity] = []
    @State private var cachedSharedDiveCount = 0
    @State private var cachedDiveRows: [DiveLogbookRowDisplayData] = []
    @State private var cachedAssociatedTripRows: [DiveBuddyTripRowDisplayData] = []
    @State private var cachedTaggedMediaItems: [DiveMediaPhoto] = []
    @State private var cachedTaggedMediaTimeZoneOffsetByID: [UUID: Int?] = [:]

    init(buddy: DiveBuddy) {
        self.buddy = buddy
        let buddyID = buddy.id
        _buddyDiveTags = Query(
            filter: #Predicate<DiveBuddyTag> { $0.buddyID == buddyID },
            sort: [SortDescriptor(\.id, order: .forward)]
        )
        _buddyMediaTags = Query(
            filter: #Predicate<DiveMediaBuddyTag> { $0.buddyID == buddyID },
            sort: [SortDescriptor(\.id, order: .forward)]
        )
    }

    private var ownerProfileID: UUID? {
        accountSession.currentProfile?.id
    }

    private var headerSharedDiveCount: Int {
        max(cachedSharedDiveCount, buddyDiveTags.count)
    }

    private var buddyDetailLoadToken: String {
        [
            buddy.id.uuidString,
            "\(buddyDiveTags.count)",
            "\(buddyMediaTags.count)",
            diveDisplayUnitSystem.rawValue,
            automaticallyRenumberDives ? "1" : "0",
        ].joined(separator: "|")
    }

    private var taggedMediaSectionItemCount: Int {
        max(cachedTaggedMediaItems.count, taggedMediaTagCount)
    }

    private var taggedMediaTagCount: Int {
        guard showsSecondarySections else { return buddyMediaTags.count }
        return cachedTaggedMediaItems.count
    }

    var body: some View {
        if DiveBuddySelfRepresentation.isSelfBuddy(buddy, owner: accountSession.currentProfile) {
            ProfileView()
        } else {
            buddyDetailsPage
        }
    }

    private var buddyDetailsPage: some View {
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

                    if showsSecondarySections {
                        if taggedMediaSectionItemCount > 0 {
                            taggedMediaSection
                        }

                        if !cachedAssociatedTripRows.isEmpty {
                            tripsTogetherSection
                        }

                        divesTogetherSection
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    } else {
                        Spacer(minLength: 0)
                    }
                }
                .padding(AppTheme.Spacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        )
        .navigationDestination(for: UUID.self) { diveID in
            if let activity = cachedSharedDives.first(where: { $0.id == diveID }) {
                ViewSingleActivity(activity: activity)
            }
        }
        .task(id: buddyDetailLoadToken) {
            await Task.yield()
            loadSecondarySections()
            showsSecondarySections = true
        }
        .hidesBottomTabBarWhenPushed()
        .onAppear {
            DiveMediaScopeCache.shared.activateScope(.buddyDetail(buddy.id))
        }
        .onDisappear {
            DiveMediaScopeCache.shared.deactivateScope(.buddyDetail(buddy.id))
        }
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
            guard buddy.contactsIdentifier != nil else { return }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(350))
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

    private func loadSecondarySections() {
        guard let ownerProfileID else { return }

        let sharedDives = DiveBuddyRosterPresentation.sharedDiveActivities(
            from: buddyDiveTags,
            ownerProfileID: ownerProfileID
        )
        cachedSharedDives = sharedDives
        cachedSharedDiveCount = sharedDives.count

        let ownerDiveActivities = fetchOwnerDiveActivities(ownerProfileID: ownerProfileID)
        cachedDiveRows = DiveBuddyRosterPresentation.sharedDiveRowDisplayData(
            sharedDives: sharedDives,
            unitSystem: diveDisplayUnitSystem,
            useChronologicalNumbers: automaticallyRenumberDives,
            numberingActivities: ownerDiveActivities
        )

        let ownerTrips = fetchOwnerTrips(ownerProfileID: ownerProfileID)
        cachedAssociatedTripRows = DiveBuddyTripPresentation.sortedAssociatedTrips(
            DiveBuddyTripPresentation.associatedTrips(
                buddyID: buddy.id,
                ownerProfileID: ownerProfileID,
                trips: ownerTrips,
                sharedDiveIDs: Set(sharedDives.map(\.id))
            )
        ).map { DiveBuddyTripPresentation.rowDisplayData(for: $0) }

        let ownerDiveActivityIDs = Set(ownerDiveActivities.map(\.id))
        let offsetByActivityID = Dictionary(
            uniqueKeysWithValues: ownerDiveActivities.map { ($0.id, $0.timeZoneOffsetSeconds) }
        )
        cachedTaggedMediaItems = DiveBuddyTaggedMediaPresentation.resolvedTaggedMediaPhotos(
            tags: buddyMediaTags,
            ownerDiveActivityIDs: ownerDiveActivityIDs,
            modelContext: modelContext
        )
        cachedTaggedMediaTimeZoneOffsetByID = DiveBuddyTaggedMediaPresentation.timeZoneOffsetByMediaID(
            tags: buddyMediaTags,
            ownerDiveActivityIDs: ownerDiveActivityIDs,
            timeZoneOffsetByActivityID: offsetByActivityID
        )
    }

    private func fetchOwnerDiveActivities(ownerProfileID: UUID) -> [DiveActivity] {
        let descriptor = FetchDescriptor<DiveActivity>(
            predicate: #Predicate { $0.ownerProfileID == ownerProfileID },
            sortBy: [
                SortDescriptor(\.startTime, order: .reverse),
                SortDescriptor(\.id, order: .forward),
            ]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchOwnerTrips(ownerProfileID: UUID) -> [DiveTrip] {
        let descriptor = FetchDescriptor<DiveTrip>(
            predicate: #Predicate { $0.ownerProfileID == ownerProfileID },
            sortBy: [
                SortDescriptor(\.startDate, order: .reverse),
                SortDescriptor(\.createdAt, order: .reverse),
            ]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
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

            Text(DiveBuddyRosterPresentation.sharedDiveCountLabel(headerSharedDiveCount))
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

    private var taggedMediaSection: some View {
        ExpandableDetailSection(
            title: DiveBuddyTaggedMediaPresentation.sectionTitle,
            itemCount: taggedMediaSectionItemCount,
            accessibilityIdentifier: "DiveBuddyDetails.TaggedMedia"
        ) {
            FieldGuideTaggedMediaGalleryView(
                mediaItems: cachedTaggedMediaItems,
                timeZoneOffsetByMediaID: cachedTaggedMediaTimeZoneOffsetByID,
                showsTitle: false,
                previewAccessibilityIdentifier: "DiveBuddyDetails.TaggedMediaPreview",
                carouselAccessibilityIdentifier: "DiveBuddyDetails.TaggedMediaCarousel"
            )
        }
    }

    private var tripsTogetherSection: some View {
        ExpandableDetailSection(
            title: DiveBuddyTripPresentation.sectionTitle,
            itemCount: cachedAssociatedTripRows.count,
            accessibilityIdentifier: "DiveBuddyDetails.TripsTogether"
        ) {
            EmptyView()
        } content: {
            DiveBuddyTripListRows(
                rows: cachedAssociatedTripRows,
                listAccessibilityIdentifier: "DiveBuddyDetails.TripList"
            )
        }
    }

    private var divesTogetherSection: some View {
        ExpandableDetailSection(
            title: "Dives together",
            itemCount: cachedSharedDiveCount,
            scrollsExpandedContent: ExpandableDetailSectionPresentation.buddyDetailScrollsExpandedDiveList,
            accessibilityIdentifier: "DiveBuddyDetails.DivesTogether"
        ) {
            Text("No dives tagged with this buddy yet.")
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("DiveBuddyDetails.EmptyDives")
        } content: {
            LinkedDiveLogbookListRows(
                rows: cachedDiveRows,
                listAccessibilityIdentifier: "DiveBuddyDetails.DiveList"
            )
        }
    }
}
