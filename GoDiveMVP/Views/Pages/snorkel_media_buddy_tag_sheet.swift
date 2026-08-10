import SwiftData
import SwiftUI

/// Roster picker to add a buddy tag on snorkel media.
struct SnorkelMediaBuddyTagPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession

    @Query private var ownedBuddies: [DiveBuddy]

    let media: SnorkelMediaPhoto
    let snorkel: SnorkelActivity
    let onTagged: () -> Void

    @State private var taggedBuddyIDs: Set<UUID> = []
    @State private var draftIncludesSelfWithoutBuddyID = false
    @State private var draftRosterOverrides: [UUID: DiveBuddy] = [:]
    @State private var selfBuddyID: UUID?
    @State private var tagErrorMessage: String?
    @State private var showsAddBuddySheet = false
    @State private var searchQuery = ""
    @FocusState private var isSearchFocused: Bool

    init(
        media: SnorkelMediaPhoto,
        snorkel: SnorkelActivity,
        onTagged: @escaping () -> Void
    ) {
        self.media = media
        self.snorkel = snorkel
        self.onTagged = onTagged
        let filterOwnerID = snorkel.ownerProfileID
        _ownedBuddies = Query(
            filter: #Predicate<DiveBuddy> { $0.ownerProfileID == filterOwnerID },
            sort: [SortDescriptor(\DiveBuddy.displayName, order: .forward)]
        )
    }

    private var draftState: DiveMediaBuddyTagDraftPresentation.DraftState {
        DiveMediaBuddyTagDraftPresentation.DraftState(
            taggedBuddyIDs: taggedBuddyIDs,
            includesSelfWithoutBuddyID: draftIncludesSelfWithoutBuddyID
        )
    }

    private var rosterByID: [UUID: DiveBuddy] {
        var map = Dictionary(uniqueKeysWithValues: ownedBuddies.map { ($0.id, $0) })
        for (id, buddy) in draftRosterOverrides {
            map[id] = buddy
        }
        return map
    }

    private var rosterBuddiesExcludingSelf: [DiveBuddy] {
        guard let owner = accountSession.currentProfile else { return ownedBuddies }
        return ownedBuddies.filter { !DiveBuddySelfRepresentation.isSelfBuddy($0, owner: owner) }
    }

    private var filteredBuddies: [DiveBuddy] {
        rosterBuddiesExcludingSelf.filter {
            TaggingSheetSelectionPresentation.matchesSearchQuery($0.displayName, query: searchQuery)
        }
    }

    private var isSelfTaggedOnMedia: Bool {
        draftState.isSelfTagged(selfBuddyID: selfBuddyID)
    }

    private var showsSelfRow: Bool {
        guard accountSession.currentProfile != nil else { return false }
        let title = DiveBuddySelfRepresentation.pickerRowTitle
        let subtitle = selfSubtitle ?? ""
        return TaggingSheetSelectionPresentation.matchesSearchQuery(title, query: searchQuery)
            || TaggingSheetSelectionPresentation.matchesSearchQuery(subtitle, query: searchQuery)
    }

    private var selfSubtitle: String? {
        guard let owner = accountSession.currentProfile else { return nil }
        let name = owner.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.caseInsensitiveCompare("Diver") != .orderedSame else { return nil }
        return name
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                pickerBody
                TaggingSheetBottomSearchChrome(
                    searchText: $searchQuery,
                    isSearchFocused: $isSearchFocused,
                    placeholder: "Search buddies",
                    searchFieldAccessibilityIdentifier: "SnorkelMediaBuddyTagPicker.SearchField",
                    cancelAccessibilityIdentifier: "SnorkelMediaBuddyTagPicker.SearchCancel"
                )
            }
            .taggingSheetToolbar(
                cancelAccessibilityIdentifier: DiveMediaBuddyTagPresentation.cancelAccessibilityIdentifier,
                doneAccessibilityIdentifier: DiveMediaBuddyTagPresentation.doneAccessibilityIdentifier,
                doneTitle: DiveMediaBuddyTagPresentation.doneButtonTitle,
                plusAccessibilityIdentifier: DiveMediaBuddyTagPresentation.addBuddyAccessibilityIdentifier,
                plusAccessibilityLabel: DiveMediaBuddyTagPresentation.addBuddyAccessibilityLabel,
                onCancel: discardDraftAndDismiss,
                onDone: commitDraftTags,
                onPlus: { showsAddBuddySheet = true }
            )
            .sheet(isPresented: $showsAddBuddySheet) {
                DiveActivityAddBuddySheet { buddy in
                    taggedBuddyIDs.insert(buddy.id)
                    draftRosterOverrides[buddy.id] = buddy
                }
            }
        }
        .diveActivityOverviewPanelModalSheetPresentation()
        .onAppear(perform: reloadTaggedBuddyIDs)
        .alert("Could not save tag", isPresented: tagErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(tagErrorMessage ?? "Try again.")
        }
    }

    @ViewBuilder
    private var pickerBody: some View {
        if rosterBuddiesExcludingSelf.isEmpty, accountSession.currentProfile == nil {
            Text("No buddies in your roster yet. Tap + to add someone and tag them on this photo.")
                .font(.body)
                .foregroundStyle(AppTheme.Colors.tabUnselected)
                .multilineTextAlignment(.center)
                .padding(AppTheme.Spacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("SnorkelMediaBuddyTagPicker.EmptyRoster")
        } else if !showsSelfRow, filteredBuddies.isEmpty {
            if rosterBuddiesExcludingSelf.isEmpty {
                Text("No other buddies in your roster yet. Tap + to add someone and tag them on this photo.")
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
                    .multilineTextAlignment(.center)
                    .padding(AppTheme.Spacing.lg)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("SnorkelMediaBuddyTagPicker.EmptyRoster")
            } else {
                ContentUnavailableView.search(text: searchQuery)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            buddyList
        }
    }

    private var buddyList: some View {
        TaggingSheetListChrome {
            if showsSelfRow, let owner = accountSession.currentProfile {
                TaggingSheetListRowContainer(showsDivider: !filteredBuddies.isEmpty) {
                    TaggingSheetSelectionRow(
                        title: DiveBuddySelfRepresentation.pickerRowTitle,
                        subtitle: selfSubtitle,
                        isSelected: isSelfTaggedOnMedia,
                        accessibilityValueSelected: "Tagged on this photo",
                        accessibilityValueUnselected: "Not tagged on this photo",
                        onTap: { toggleSelfTag(owner: owner) },
                        leading: {
                            ProfileAvatarView(
                                profilePhoto: owner.profilePhoto,
                                diameter: TaggingSheetSelectionPresentation.leadingArtDiameter,
                                iconFont: .callout
                            )
                        }
                    )
                    .accessibilityIdentifier("SnorkelMediaBuddyTagPicker.Self")
                }
            }

            ForEach(Array(filteredBuddies.enumerated()), id: \.element.id) { index, buddy in
                TaggingSheetListRowContainer(showsDivider: index < filteredBuddies.count - 1) {
                    TaggingSheetSelectionRow(
                        title: buddy.displayName,
                        isSelected: taggedBuddyIDs.contains(buddy.id),
                        accessibilityValueSelected: "Tagged on this photo",
                        accessibilityValueUnselected: "Not tagged on this photo",
                        onTap: { toggleTag(buddy) },
                        leading: {
                            ProfileAvatarView(
                                profilePhoto: buddy.profilePhoto,
                                diameter: TaggingSheetSelectionPresentation.leadingArtDiameter,
                                iconFont: .callout,
                                placeholderInitials: DiveBuddyPresentation.initials(from: buddy.displayName)
                            )
                        }
                    )
                    .accessibilityIdentifier("SnorkelMediaBuddyTagPicker.Row.\(buddy.id.uuidString)")
                }
            }
        }
    }

    private var tagErrorPresented: Binding<Bool> {
        Binding(
            get: { tagErrorMessage != nil },
            set: { if !$0 { tagErrorMessage = nil } }
        )
    }

    private func reloadTaggedBuddyIDs() {
        let tags = (try? SnorkelMediaBuddyAssociation.tags(
            forMediaPhotoID: media.id,
            modelContext: modelContext
        )) ?? []
        let draft = DiveMediaBuddyTagDraftPresentation.DraftState(
            mediaPhotoID: media.id,
            tags: tags
        )
        taggedBuddyIDs = draft.taggedBuddyIDs
        draftIncludesSelfWithoutBuddyID = draft.includesSelfWithoutBuddyID
        selfBuddyID = DiveBuddySelfRepresentation.resolveSelfBuddyID(
            owner: accountSession.currentProfile,
            modelContext: modelContext
        )
    }

    private func toggleSelfTag(owner: UserProfile) {
        var draft = draftState
        draft.toggleSelf(selfBuddyID: selfBuddyID)
        taggedBuddyIDs = draft.taggedBuddyIDs
        draftIncludesSelfWithoutBuddyID = draft.includesSelfWithoutBuddyID
    }

    private func toggleTag(_ buddy: DiveBuddy) {
        if taggedBuddyIDs.contains(buddy.id) {
            taggedBuddyIDs.remove(buddy.id)
        } else {
            taggedBuddyIDs.insert(buddy.id)
        }
    }

    private func discardDraftAndDismiss() {
        dismiss()
    }

    private func commitDraftTags() {
        do {
            try SnorkelMediaBuddyTagDraftPresentation.apply(
                draft: draftState,
                media: media,
                snorkel: snorkel,
                owner: accountSession.currentProfile,
                rosterByID: rosterByID,
                modelContext: modelContext
            )
            onTagged()
            dismiss()
        } catch {
            tagErrorMessage = error.localizedDescription
        }
    }
}
