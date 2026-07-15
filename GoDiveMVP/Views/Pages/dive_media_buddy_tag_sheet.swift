import SwiftData
import SwiftUI

/// Roster picker to add a buddy tag on dive media.
struct DiveMediaBuddyTagPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession

    @Query private var ownedBuddies: [DiveBuddy]

    let media: DiveMediaPhoto
    let dive: DiveActivity
    let onTagged: () -> Void

    @State private var taggedBuddyIDs: Set<UUID> = []
    @State private var draftIncludesSelfWithoutBuddyID = false
    @State private var draftRosterOverrides: [UUID: DiveBuddy] = [:]
    @State private var selfBuddyID: UUID?
    @State private var tagErrorMessage: String?
    @State private var showsAddBuddySheet = false

    init(
        media: DiveMediaPhoto,
        dive: DiveActivity,
        onTagged: @escaping () -> Void
    ) {
        self.media = media
        self.dive = dive
        self.onTagged = onTagged
        let filterOwnerID = dive.ownerProfileID
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

    private var ownerProfileID: UUID? {
        accountSession.currentProfile?.id
    }

    private var rosterBuddiesExcludingSelf: [DiveBuddy] {
        guard let owner = accountSession.currentProfile else { return ownedBuddies }
        return ownedBuddies.filter { !DiveBuddySelfRepresentation.isSelfBuddy($0, owner: owner) }
    }

    private var isSelfTaggedOnMedia: Bool {
        draftState.isSelfTagged(selfBuddyID: selfBuddyID)
    }

    var body: some View {
        NavigationStack {
            List {
                if let owner = accountSession.currentProfile {
                    Section {
                        Button {
                            toggleSelfTag(owner: owner)
                        } label: {
                            DiveMediaBuddySelfTagPickerRow(
                                owner: owner,
                                isTaggedOnMedia: isSelfTaggedOnMedia
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(
                            top: 0,
                            leading: AppTheme.Spacing.md,
                            bottom: 0,
                            trailing: AppTheme.Spacing.md
                        ))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .accessibilityLabel(DiveBuddySelfRepresentation.pickerRowTitle)
                        .accessibilityValue(
                            isSelfTaggedOnMedia
                                ? "Tagged on this photo"
                                : "Not tagged on this photo"
                        )
                        .accessibilityIdentifier("DiveMediaBuddyTagPicker.Self")
                    } header: {
                        Text(DiveBuddySelfRepresentation.pickerRowTitle)
                    }
                }

                if rosterBuddiesExcludingSelf.isEmpty {
                    Section {
                        Text("No other buddies in your roster yet. Tap + to add someone and tag them on this photo.")
                            .font(.body)
                            .foregroundStyle(AppTheme.Colors.tabUnselected)
                            .accessibilityIdentifier("DiveMediaBuddyTagPicker.EmptyRoster")
                    }
                } else {
                    Section {
                        ForEach(rosterBuddiesExcludingSelf, id: \.id) { buddy in
                            Button {
                                toggleTag(buddy)
                            } label: {
                                DiveMediaBuddyTagPickerRow(
                                    buddy: buddy,
                                    isTaggedOnMedia: taggedBuddyIDs.contains(buddy.id)
                                )
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(
                                top: 0,
                                leading: AppTheme.Spacing.md,
                                bottom: 0,
                                trailing: AppTheme.Spacing.md
                            ))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .accessibilityLabel(buddy.displayName)
                            .accessibilityValue(
                                taggedBuddyIDs.contains(buddy.id)
                                    ? "Tagged on this photo"
                                    : "Not tagged on this photo"
                            )
                            .accessibilityIdentifier("DiveMediaBuddyTagPicker.Row.\(buddy.id.uuidString)")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .listRowSpacing(DiveMediaBuddyTagPickerRowLayout.listRowSpacing)
            .scrollContentBackground(.hidden)
            .appSheetContentTopSpacing()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(DiveMediaBuddyTagPresentation.sheetTitle)
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .cancellationAction) {
                    // Plain toolbar control — avoid nested overlay glass inside Liquid Glass nav chrome.
                    Button(action: discardDraftAndDismiss) {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(DiveMediaBuddyTagPresentation.cancelAccessibilityLabel)
                    .accessibilityIdentifier(DiveMediaBuddyTagPresentation.cancelAccessibilityIdentifier)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsAddBuddySheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(DiveMediaBuddyTagPresentation.addBuddyAccessibilityLabel)
                    .accessibilityIdentifier(DiveMediaBuddyTagPresentation.addBuddyAccessibilityIdentifier)
                }
                // Keep **+** and **Done** as separate Liquid Glass borders (not one shared capsule).
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .confirmationAction) {
                    Button(DiveMediaBuddyTagPresentation.doneButtonTitle) {
                        commitDraftTags()
                    }
                    .buttonStyle(.glassProminent)
                    .accessibilityIdentifier(DiveMediaBuddyTagPresentation.doneAccessibilityIdentifier)
                }
            }
            .sheet(isPresented: $showsAddBuddySheet) {
                DiveActivityAddBuddySheet { buddy in
                    taggedBuddyIDs.insert(buddy.id)
                    draftRosterOverrides[buddy.id] = buddy
                }
            }
        }
        .diveMediaTagPickerSheetPresentation()
        .onAppear(perform: reloadTaggedBuddyIDs)
        .alert("Could not save tag", isPresented: tagErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(tagErrorMessage ?? "Try again.")
        }
    }

    private var tagErrorPresented: Binding<Bool> {
        Binding(
            get: { tagErrorMessage != nil },
            set: { if !$0 { tagErrorMessage = nil } }
        )
    }

    private func reloadTaggedBuddyIDs() {
        let tags = (try? DiveMediaBuddyAssociation.tags(
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
            try DiveMediaBuddyTagDraftPresentation.apply(
                draft: draftState,
                media: media,
                dive: dive,
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

// MARK: - Rows

private enum DiveMediaBuddyTagPickerRowLayout {
    static let avatarDiameter: CGFloat = 36
    static let rowPadding = EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
    static let listRowSpacing: CGFloat = 6
    static let cornerRadius: CGFloat = 10
}

private struct DiveMediaBuddySelfTagPickerRow: View {
    let owner: UserProfile
    let isTaggedOnMedia: Bool

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ProfileAvatarView(
                profilePhoto: owner.profilePhoto,
                diameter: DiveMediaBuddyTagPickerRowLayout.avatarDiameter,
                iconFont: .callout
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(DiveBuddySelfRepresentation.pickerRowTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.tabUnselected)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isTaggedOnMedia {
                Image(systemName: "checkmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.tabSelected)
                    .accessibilityHidden(true)
            }
        }
        .padding(DiveMediaBuddyTagPickerRowLayout.rowPadding)
        .background(rowBackground)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String? {
        let name = owner.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.caseInsensitiveCompare("Diver") != .orderedSame else { return nil }
        return name
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: DiveMediaBuddyTagPickerRowLayout.cornerRadius, style: .continuous)
            .fill(
                isTaggedOnMedia
                    ? AppTheme.Colors.tabSelected.opacity(0.14)
                    : AppTheme.Colors.surfaceElevated
            )
            .overlay {
                RoundedRectangle(cornerRadius: DiveMediaBuddyTagPickerRowLayout.cornerRadius, style: .continuous)
                    .stroke(
                        isTaggedOnMedia ? AppTheme.Colors.tabSelected.opacity(0.55) : Color.clear,
                        lineWidth: 1.5
                    )
            }
    }
}

private struct DiveMediaBuddyTagPickerRow: View {
    let buddy: DiveBuddy
    let isTaggedOnMedia: Bool

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ProfileAvatarView(
                profilePhoto: buddy.profilePhoto,
                diameter: DiveMediaBuddyTagPickerRowLayout.avatarDiameter,
                iconFont: .callout,
                placeholderInitials: DiveBuddyPresentation.initials(from: buddy.displayName)
            )

            Text(buddy.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isTaggedOnMedia {
                Image(systemName: "checkmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.tabSelected)
                    .accessibilityHidden(true)
            }
        }
        .padding(DiveMediaBuddyTagPickerRowLayout.rowPadding)
        .background(rowBackground)
        .accessibilityElement(children: .combine)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: DiveMediaBuddyTagPickerRowLayout.cornerRadius, style: .continuous)
            .fill(
                isTaggedOnMedia
                    ? AppTheme.Colors.tabSelected.opacity(0.14)
                    : AppTheme.Colors.surfaceElevated
            )
            .overlay {
                RoundedRectangle(cornerRadius: DiveMediaBuddyTagPickerRowLayout.cornerRadius, style: .continuous)
                    .stroke(
                        isTaggedOnMedia ? AppTheme.Colors.tabSelected.opacity(0.55) : Color.clear,
                        lineWidth: 1.5
                    )
            }
    }
}
