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

    var body: some View {
        NavigationStack {
            Form {
                if let loadErrorMessage {
                    Section {
                        Text(loadErrorMessage)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                    .listRowBackground(Color.clear)
                }

                Section("On this dive") {
                    let applied = draftAppliedTags
                    if applied.isEmpty {
                        Text("No tags on this dive yet.")
                            .foregroundStyle(AppTheme.Colors.tabUnselected)
                            .listRowBackground(Color.clear)
                    } else {
                        DiveActivityTagChipFlow(tagNames: applied.map(\.name))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .listRowInsets(EdgeInsets(
                                top: AppTheme.Spacing.sm,
                                leading: 0,
                                bottom: AppTheme.Spacing.sm,
                                trailing: 0
                            ))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }

                Section {
                    if ownerTags.isEmpty {
                        Text("Tap + to create a tag, or add one from your roster below.")
                            .foregroundStyle(AppTheme.Colors.tabUnselected)
                            .accessibilityIdentifier("DiveTagsEditSheet.EmptyRoster")
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(ownerTags, id: \.id) { tag in
                            Button {
                                toggleDraftApplied(tag)
                            } label: {
                                HStack {
                                    Text(tag.name)
                                        .foregroundStyle(AppTheme.Colors.textPrimary)
                                    Spacer(minLength: AppTheme.Spacing.sm)
                                    if isDraftApplied(tag) {
                                        Image(systemName: "checkmark")
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(AppTheme.Colors.tabSelected)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .accessibilityLabel(tag.name)
                            .accessibilityValue(
                                isDraftApplied(tag) ? "On this dive" : "Not on this dive"
                            )
                        }
                    }
                } header: {
                    Text("Your tags")
                } footer: {
                    Text("Tags are saved to your account and can be reused on other dives.")
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppGlassToolbarCancelButton(
                        action: { dismiss() },
                        accessibilityIdentifier: "DiveTagsEditSheet.Cancel"
                    )
                }
                ToolbarItem(placement: .topBarTrailing) {
                    AppSheetToolbarPlusButton(
                        action: { showsCreateTagSheet = true },
                        accessibilityIdentifier: "DiveTagsEditSheet.CreateTag",
                        accessibilityLabel: "Create tag"
                    )
                }

                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .confirmationAction) {
                    AppGlassProminentDoneButton(
                        action: commitDraftTagsAndDismiss,
                        accessibilityIdentifier: "DiveTagsEditSheet.Done"
                    )
                }
            }
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

    private var draftAppliedTags: [ActivityTag] {
        ownerTags
            .filter { draftAppliedTagIDs.contains($0.id) }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
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
