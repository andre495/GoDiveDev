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

    var body: some View {
        NavigationStack {
            Form {
                if let loadErrorMessage {
                    Section {
                        Text(loadErrorMessage)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                }

                Section("On this dive") {
                    let applied = ActivityTagStore.sortedTags(on: activity)
                    if applied.isEmpty {
                        Text("No tags on this dive yet.")
                            .foregroundStyle(AppTheme.Colors.tabUnselected)
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
                    } else {
                        ForEach(ownerTags, id: \.id) { tag in
                            Button {
                                toggleApplied(tag)
                            } label: {
                                HStack {
                                    Text(tag.name)
                                        .foregroundStyle(AppTheme.Colors.textPrimary)
                                    Spacer(minLength: AppTheme.Spacing.sm)
                                    if ActivityTagStore.isApplied(tag, on: activity) {
                                        Image(systemName: "checkmark")
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(AppTheme.Colors.tabSelected)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(tag.name)
                            .accessibilityValue(
                                ActivityTagStore.isApplied(tag, on: activity) ? "On this dive" : "Not on this dive"
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
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showsCreateTagSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.tabSelected)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Create tag")
                    .accessibilityIdentifier("DiveTagsEditSheet.CreateTag")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.Colors.tabSelected)
                    .accessibilityIdentifier("DiveTagsEditSheet.Done")
                }
            }
            .task(id: ownerProfileID) {
                await reloadOwnerTags()
            }
        }
        .diveActivityTagsSheetPresentation()
        .sheet(isPresented: $showsCreateTagSheet) {
            DiveActivityCreateTagSheet(tagName: $newTagName) {
                createAndApplyTag()
            }
        }
        .accessibilityIdentifier("DiveTagsEditSheet.Root")
    }

    private func toggleApplied(_ tag: ActivityTag) {
        if ActivityTagStore.isApplied(tag, on: activity) {
            ActivityTagStore.removeTag(tag, from: activity)
        } else {
            ActivityTagStore.applyTag(tag, to: activity)
        }
    }

    private func createAndApplyTag() {
        do {
            guard let tag = try ActivityTagStore.findOrCreateTag(
                rawName: newTagName,
                ownerProfileID: ownerProfileID,
                modelContext: modelContext
            ) else { return }
            ActivityTagStore.applyTag(tag, to: activity)
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
}

// MARK: - Create tag

private struct DiveActivityCreateTagSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var tagName: String
    var onCreate: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Tag name", text: $tagName)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("DiveTagsCreateSheet.NameField")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("New tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        tagName = ""
                        dismiss()
                    }
                    .accessibilityIdentifier("DiveTagsCreateSheet.Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onCreate()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.Colors.tabSelected)
                    .disabled(tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("DiveTagsCreateSheet.Add")
                }
            }
        }
        .diveActivityFieldSheetPresentation()
        .accessibilityIdentifier("DiveTagsCreateSheet.Root")
    }
}
