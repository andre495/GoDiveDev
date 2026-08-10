import SwiftData
import SwiftUI

/// Pick roster buddies to invite on a planned trip (blue overview-panel modal).
struct TripPlannedBuddyPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let trip: DiveTrip?
    private var selectedBuddyIDs: Binding<Set<UUID>>?
    /// When committing onto an existing trip, parent can observe share-offer candidates.
    var onCommittedShareOfferCandidates: (([DiveTripShareOfferPresentation.Candidate], DiveTrip) -> Void)?

    @Query private var ownedBuddies: [DiveBuddy]

    @State private var showsAddBuddySheet = false
    @State private var draftBuddyIDs: Set<UUID> = []
    @State private var draftRosterOverrides: [UUID: DiveBuddy] = [:]
    @State private var previousBuddyIDs: Set<UUID> = []
    @State private var shareOfferQueue = DiveTripShareOfferQueue()
    @State private var searchQuery = ""
    @FocusState private var isSearchFocused: Bool

    /// Persist selection onto an existing trip on **Done**.
    init(
        trip: DiveTrip,
        onCommittedShareOfferCandidates: (([DiveTripShareOfferPresentation.Candidate], DiveTrip) -> Void)? = nil
    ) {
        self.trip = trip
        self.selectedBuddyIDs = nil
        self.onCommittedShareOfferCandidates = onCommittedShareOfferCandidates
        let filterOwnerID = trip.ownerProfileID
        _ownedBuddies = Query(
            filter: #Predicate<DiveBuddy> { $0.ownerProfileID == filterOwnerID },
            sort: [SortDescriptor(\DiveBuddy.displayName, order: .forward)]
        )
    }

    /// Draft selection for trip create / edit forms (applied when the parent sheet saves).
    init(selectedBuddyIDs: Binding<Set<UUID>>, ownerProfileID: UUID?) {
        self.trip = nil
        self.selectedBuddyIDs = selectedBuddyIDs
        self.onCommittedShareOfferCandidates = nil
        let filterOwnerID = ownerProfileID ?? Self.noOwnerQueryToken
        _ownedBuddies = Query(
            filter: #Predicate<DiveBuddy> { $0.ownerProfileID == filterOwnerID },
            sort: [SortDescriptor(\DiveBuddy.displayName, order: .forward)]
        )
    }

    private static let noOwnerQueryToken = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private var rosterByID: [UUID: DiveBuddy] {
        var map = Dictionary(uniqueKeysWithValues: ownedBuddies.map { ($0.id, $0) })
        for (id, buddy) in draftRosterOverrides {
            map[id] = buddy
        }
        return map
    }

    private var filteredBuddies: [DiveBuddy] {
        ownedBuddies.filter {
            TaggingSheetSelectionPresentation.matchesSearchQuery($0.displayName, query: searchQuery)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if ownedBuddies.isEmpty {
                    Text(DiveTripPresentation.tripPlannedBuddyPickerEmptyRosterMessage)
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.tabUnselected)
                        .multilineTextAlignment(.center)
                        .padding(AppTheme.Spacing.lg)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("TripPlannedBuddyPicker.EmptyRoster")
                } else if filteredBuddies.isEmpty {
                    ContentUnavailableView.search(text: searchQuery)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TaggingSheetListChrome {
                        ForEach(Array(filteredBuddies.enumerated()), id: \.element.id) { index, buddy in
                            TaggingSheetListRowContainer(showsDivider: index < filteredBuddies.count - 1) {
                                TaggingSheetSelectionRow(
                                    title: buddy.displayName,
                                    isSelected: draftBuddyIDs.contains(buddy.id),
                                    accessibilityValueSelected: "On this trip",
                                    accessibilityValueUnselected: "Not on this trip",
                                    onTap: { toggleBuddy(buddy) },
                                    leading: {
                                        ProfileAvatarView(
                                            profilePhoto: buddy.profilePhoto,
                                            diameter: TaggingSheetSelectionPresentation.leadingArtDiameter,
                                            iconFont: .callout,
                                            placeholderInitials: DiveBuddyPresentation.initials(from: buddy.displayName)
                                        )
                                    }
                                )
                                .accessibilityIdentifier("TripPlannedBuddyPicker.Row.\(buddy.id.uuidString)")
                            }
                        }
                    }
                }

                TaggingSheetBottomSearchChrome(
                    searchText: $searchQuery,
                    isSearchFocused: $isSearchFocused,
                    placeholder: "Search buddies",
                    searchFieldAccessibilityIdentifier: "TripPlannedBuddyPicker.SearchField",
                    cancelAccessibilityIdentifier: "TripPlannedBuddyPicker.SearchCancel"
                )
            }
            .taggingSheetToolbar(
                cancelAccessibilityIdentifier: DiveTripPresentation.plannedBuddyPickerCancelAccessibilityIdentifier,
                doneAccessibilityIdentifier: DiveTripPresentation.plannedBuddyPickerDoneAccessibilityIdentifier,
                plusAccessibilityIdentifier: DiveTripPresentation.plannedBuddyPickerAddBuddyAccessibilityIdentifier,
                plusAccessibilityLabel: DiveTripPresentation.addPlannedBuddyAccessibilityLabel,
                onCancel: { dismiss() },
                onDone: commitAndFinish,
                onPlus: { showsAddBuddySheet = true }
            )
        }
        .diveActivityOverviewPanelModalSheetPresentation()
        .onAppear(perform: reloadDraftBuddyIDs)
        .sheet(isPresented: $showsAddBuddySheet) {
            DiveActivityAddBuddySheet { buddy in
                draftRosterOverrides[buddy.id] = buddy
                draftBuddyIDs.insert(buddy.id)
            }
        }
        .alert(
            shareOfferQueue.current.map {
                DiveTripShareOfferPresentation.confirmationTitle(displayName: $0.displayName)
            } ?? "",
            isPresented: DiveTripShareOfferAlertModifier.alertBinding(queue: shareOfferQueue)
        ) {
            Button(DiveTripShareOfferPresentation.shareButtonTitle) {
                shareOfferQueue.share(modelContext: modelContext) {
                    dismiss()
                }
            }
            Button(DiveTripShareOfferPresentation.declineButtonTitle, role: .cancel) {
                shareOfferQueue.decline {
                    dismiss()
                }
            }
        } message: {
            Text(DiveTripShareOfferPresentation.confirmationMessage)
        }
        .accessibilityIdentifier("TripPlannedBuddyPicker.Root")
    }

    private func reloadDraftBuddyIDs() {
        if let trip {
            let ids = DiveTripPlannedBuddyDraftPresentation.plannedBuddyIDs(on: trip)
            previousBuddyIDs = ids
            draftBuddyIDs = ids
        } else if let selectedBuddyIDs {
            draftBuddyIDs = selectedBuddyIDs.wrappedValue
        }
    }

    private func commitAndFinish() {
        if let trip {
            let previous = previousBuddyIDs
            DiveTripPlannedBuddyDraftPresentation.apply(
                draftBuddyIDs: draftBuddyIDs,
                to: trip,
                rosterByID: rosterByID,
                modelContext: modelContext
            )
            try? modelContext.save()

            // Revoke shares for GoDive friends removed from the trip.
            let removed = previous.subtracting(draftBuddyIDs)
            let removedFriendUIDs: [String] = removed.compactMap { buddyID in
                guard let buddy = rosterByID[buddyID] else { return nil }
                return DiveBuddyFriendLinkPresentation.linkedFirebaseUID(for: buddy)
            }
            if !removedFriendUIDs.isEmpty {
                Task { @MainActor in
                    await GoDiveTripShareSync.revokeShares(for: trip, friendUIDs: removedFriendUIDs)
                    try? modelContext.save()
                }
            }

            let candidates = DiveTripShareOfferPresentation.candidates(
                previousBuddyIDs: previous,
                newBuddyIDs: draftBuddyIDs,
                rosterByID: rosterByID,
                trip: trip
            )
            onCommittedShareOfferCandidates?(candidates, trip)
            if candidates.isEmpty {
                dismiss()
            } else {
                shareOfferQueue.enqueue(candidates: candidates, for: trip)
            }
            return
        }

        selectedBuddyIDs?.wrappedValue = draftBuddyIDs
        dismiss()
    }

    private func toggleBuddy(_ buddy: DiveBuddy) {
        if draftBuddyIDs.contains(buddy.id) {
            draftBuddyIDs.remove(buddy.id)
        } else {
            draftBuddyIDs.insert(buddy.id)
        }
    }

}
