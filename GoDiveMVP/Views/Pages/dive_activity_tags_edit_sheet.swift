import SwiftData
import SwiftUI

/// Pick existing tags or create new ones for this dive.
struct DiveActivityTagsEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var activity: DiveActivity
    let ownerProfileID: UUID

    @State private var newTagName = ""
    @State private var ownerTags: [ActivityTag] = []
    @State private var loadErrorMessage: String?
    @State private var showsCreateTagSheet = false
    @State private var draftAppliedTagIDs: Set<UUID> = []
    @State private var searchQuery = ""
    @FocusState private var isSearchFocused: Bool

    private var filteredTags: [ActivityTag] {
        ownerTags.filter {
            TaggingSheetSelectionPresentation.matchesSearchQuery($0.name, query: searchQuery)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                pickerBody
                TaggingSheetBottomSearchChrome(
                    searchText: $searchQuery,
                    isSearchFocused: $isSearchFocused,
                    placeholder: "Search tags",
                    searchFieldAccessibilityIdentifier: "DiveTagsEditSheet.SearchField",
                    cancelAccessibilityIdentifier: "DiveTagsEditSheet.SearchCancel"
                )
            }
            .taggingSheetToolbar(
                cancelAccessibilityIdentifier: "DiveTagsEditSheet.Cancel",
                doneAccessibilityIdentifier: "DiveTagsEditSheet.Done",
                plusAccessibilityIdentifier: "DiveTagsEditSheet.CreateTag",
                plusAccessibilityLabel: "Create tag",
                onCancel: { dismiss() },
                onDone: commitDraftTagsAndDismiss,
                onPlus: { showsCreateTagSheet = true }
            )
            .task(id: ownerProfileID) {
                await reloadOwnerTags()
            }
        }
        .diveActivityOverviewPanelModalSheetPresentation()
        .sheet(isPresented: $showsCreateTagSheet) {
            DiveActivityCreateTagSheet(tagName: $newTagName) {
                createAndApplyTag()
            }
        }
        .accessibilityIdentifier("DiveTagsEditSheet.Root")
    }

    @ViewBuilder
    private var pickerBody: some View {
        if let loadErrorMessage {
            Text(loadErrorMessage)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(AppTheme.Spacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if ownerTags.isEmpty {
            Text("Tap + to create a tag, or add one from your roster below.")
                .font(.body)
                .foregroundStyle(AppTheme.Colors.tabUnselected)
                .multilineTextAlignment(.center)
                .padding(AppTheme.Spacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("DiveTagsEditSheet.EmptyRoster")
        } else if filteredTags.isEmpty {
            ContentUnavailableView.search(text: searchQuery)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            TaggingSheetListChrome {
                ForEach(Array(filteredTags.enumerated()), id: \.element.id) { index, tag in
                    TaggingSheetListRowContainer(showsDivider: index < filteredTags.count - 1) {
                        TaggingSheetSelectionRow(
                            title: tag.name,
                            isSelected: isDraftApplied(tag),
                            accessibilityValueSelected: "On this dive",
                            accessibilityValueUnselected: "Not on this dive",
                            onTap: { toggleDraftApplied(tag) },
                            leading: {
                                TaggingSheetSymbolLeadingArt(
                                    systemName: TaggingSheetSelectionPresentation.tagPlaceholderSystemName
                                )
                            }
                        )
                        .accessibilityIdentifier("DiveTagsEditSheet.Row.\(tag.id.uuidString)")
                    }
                }
            }
        }
    }

    private func isDraftApplied(_ tag: ActivityTag) -> Bool {
        draftAppliedTagIDs.contains(tag.id)
    }

    private func toggleDraftApplied(_ tag: ActivityTag) {
        if draftAppliedTagIDs.contains(tag.id) {
            draftAppliedTagIDs.remove(tag.id)
        } else {
            draftAppliedTagIDs.insert(tag.id)
        }
    }

    private func createAndApplyTag() {
        do {
            guard let tag = try ActivityTagStore.findOrCreateTag(
                rawName: newTagName,
                ownerProfileID: ownerProfileID,
                modelContext: modelContext
            ) else { return }
            draftAppliedTagIDs.insert(tag.id)
            newTagName = ""
            try modelContext.save()
            try reloadOwnerTagsSync()
            loadErrorMessage = nil
        } catch {
            loadErrorMessage = "Could not save that tag."
        }
    }

    @MainActor
    private func reloadOwnerTags() async {
        do {
            try reloadOwnerTagsSync()
            reloadDraftAppliedTags()
            loadErrorMessage = nil
        } catch {
            loadErrorMessage = "Could not load your tags."
        }
    }

    @MainActor
    private func reloadOwnerTagsSync() throws {
        ownerTags = try ActivityTagStore.fetchTags(
            ownerProfileID: ownerProfileID,
            modelContext: modelContext
        )
    }

    private func reloadDraftAppliedTags() {
        draftAppliedTagIDs = Set(ActivityTagStore.sortedTags(on: activity).map(\.id))
    }

    private func commitDraftTagsAndDismiss() {
        for tag in ownerTags {
            if draftAppliedTagIDs.contains(tag.id) {
                ActivityTagStore.applyTag(tag, to: activity)
            } else {
                ActivityTagStore.removeTag(tag, from: activity)
            }
        }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Create tag

private struct DiveActivityCreateTagSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var tagName: String
    var onCreate: () -> Void

    private var canAddTag: Bool {
        !tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Tag name", text: $tagName)
                        .textInputAutocapitalization(.words)
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("DiveTagsCreateSheet.NameField")
                } header: {
                    Text("Name")
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .navigationTitle("New tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppGlassToolbarCancelButton(
                        action: {
                            tagName = ""
                            dismiss()
                        },
                        accessibilityIdentifier: "DiveTagsCreateSheet.Cancel"
                    )
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppGlassProminentDoneButton(
                        action: {
                            onCreate()
                            dismiss()
                        },
                        accessibilityIdentifier: "DiveTagsCreateSheet.Add",
                        title: "Add",
                        isEnabled: canAddTag
                    )
                }
            }
        }
        .diveActivityOverviewPanelModalSheetPresentation()
        .accessibilityIdentifier("DiveTagsCreateSheet.Root")
    }
}
