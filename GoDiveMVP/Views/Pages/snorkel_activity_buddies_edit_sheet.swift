import SwiftData
import SwiftUI

/// Tag **`DiveBuddy`** roster rows on this snorkel — roster picker + **+** to create a new buddy.
struct SnorkelActivityBuddiesEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var activity: SnorkelActivity

    @Query private var ownedBuddies: [DiveBuddy]

    @State private var showsAddBuddySheet = false
    @State private var draftTaggedBuddyIDs: Set<UUID> = []
    @State private var draftRosterOverrides: [UUID: DiveBuddy] = [:]
    @State private var searchQuery = ""
    @FocusState private var isSearchFocused: Bool

    init(activity: SnorkelActivity) {
        self._activity = Bindable(wrappedValue: activity)
        let filterOwnerID = activity.ownerProfileID
        _ownedBuddies = Query(
            filter: #Predicate<DiveBuddy> { $0.ownerProfileID == filterOwnerID },
            sort: [SortDescriptor(\DiveBuddy.displayName, order: .forward)]
        )
    }

    private var rosterByID: [UUID: DiveBuddy] {
        var map = Dictionary(uniqueKeysWithValues: ownedBuddies.map { ($0.id, $0) })
        for (id, buddy) in draftRosterOverrides {
            map[id] = buddy
        }
        return map
    }

    private var rosterBuddiesSorted: [DiveBuddy] {
        ownedBuddies.sorted { lhs, rhs in
            let leftLinked = lhs.linkedFirebaseUID != nil
            let rightLinked = rhs.linkedFirebaseUID != nil
            if leftLinked != rightLinked { return leftLinked && !rightLinked }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    private var filteredBuddies: [DiveBuddy] {
        rosterBuddiesSorted.filter {
            TaggingSheetSelectionPresentation.matchesSearchQuery($0.displayName, query: searchQuery)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if ownedBuddies.isEmpty {
                    emptyRoster
                } else if filteredBuddies.isEmpty {
                    ContentUnavailableView.search(text: searchQuery)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    buddyList
                }

                TaggingSheetBottomSearchChrome(
                    searchText: $searchQuery,
                    isSearchFocused: $isSearchFocused,
                    placeholder: "Search buddies",
                    searchFieldAccessibilityIdentifier: "SnorkelBuddiesEditSheet.SearchField",
                    cancelAccessibilityIdentifier: "SnorkelBuddiesEditSheet.SearchCancel"
                )
            }
            .taggingSheetToolbar(
                cancelAccessibilityIdentifier: "SnorkelBuddiesEditSheet.Cancel",
                doneAccessibilityIdentifier: "SnorkelBuddiesEditSheet.Done",
                plusAccessibilityIdentifier: "SnorkelBuddiesEditSheet.AddBuddy",
                plusAccessibilityLabel: "Add buddy",
                onCancel: { dismiss() },
                onDone: {
                    commitDraftTaggedBuddies()
                    dismiss()
                },
                onPlus: { showsAddBuddySheet = true }
            )
        }
        .diveActivityOverviewPanelModalSheetPresentation()
        .onAppear(perform: reloadDraftTaggedBuddyIDs)
        .sheet(isPresented: $showsAddBuddySheet) {
            DiveActivityAddBuddySheet { buddy in
                draftTaggedBuddyIDs.insert(buddy.id)
                draftRosterOverrides[buddy.id] = buddy
            }
        }
        .accessibilityIdentifier("SnorkelBuddiesEditSheet.Root")
    }

    private var emptyRoster: some View {
        Text("No buddies in your roster yet. Tap + to add someone and tag them on this snorkel.")
            .font(.body)
            .foregroundStyle(AppTheme.Colors.tabUnselected)
            .multilineTextAlignment(.center)
            .padding(AppTheme.Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("SnorkelBuddiesEditSheet.EmptyRoster")
    }

    private var buddyList: some View {
        TaggingSheetListChrome {
            ForEach(Array(filteredBuddies.enumerated()), id: \.element.id) { index, buddy in
                TaggingSheetListRowContainer(showsDivider: index < filteredBuddies.count - 1) {
                    TaggingSheetSelectionRow(
                        title: buddy.displayName,
                        subtitle: buddy.linkedFirebaseUID != nil ? "GoDive friend" : nil,
                        isSelected: isBuddyTaggedOnSnorkel(buddy),
                        accessibilityValueSelected: "Tagged on this snorkel",
                        accessibilityValueUnselected: "Not on this snorkel",
                        onTap: { toggleBuddyOnSnorkel(buddy) },
                        leading: {
                            ProfileAvatarView(
                                profilePhoto: buddy.profilePhoto,
                                diameter: TaggingSheetSelectionPresentation.leadingArtDiameter,
                                iconFont: .callout,
                                placeholderInitials: DiveBuddyPresentation.initials(from: buddy.displayName)
                            )
                        }
                    )
                    .accessibilityIdentifier("SnorkelBuddiesEditSheet.RosterRow.\(buddy.id.uuidString)")
                }
            }
        }
    }

    private func reloadDraftTaggedBuddyIDs() {
        draftTaggedBuddyIDs = SnorkelBuddyActivityTagDraftPresentation.taggedBuddyIDs(on: activity)
    }

    private func isBuddyTaggedOnSnorkel(_ buddy: DiveBuddy) -> Bool {
        draftTaggedBuddyIDs.contains(buddy.id)
    }

    private func toggleBuddyOnSnorkel(_ buddy: DiveBuddy) {
        if draftTaggedBuddyIDs.contains(buddy.id) {
            draftTaggedBuddyIDs.remove(buddy.id)
        } else {
            draftTaggedBuddyIDs.insert(buddy.id)
        }
    }

    private func commitDraftTaggedBuddies() {
        SnorkelBuddyActivityTagDraftPresentation.apply(
            draftTaggedBuddyIDs: draftTaggedBuddyIDs,
            to: activity,
            rosterByID: rosterByID,
            modelContext: modelContext
        )
        try? modelContext.save()
    }
}
