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

    var body: some View {
        NavigationStack {
            Form {
                if let loadErrorMessage {
                    Section {
                        Text(loadErrorMessage)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                }

                Section {
                    HStack {
                        TextField("New tag", text: $newTagName)
                            .textInputAutocapitalization(.words)
                        Button("Add") {
                            createAndApplyTag()
                        }
                        .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } header: {
                    Text("Create tag")
                } footer: {
                    Text("Tags are saved to your account and can be reused on other dives.")
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

                Section("Your tags") {
                    if ownerTags.isEmpty {
                        Text("Create a tag above to get started.")
                            .foregroundStyle(AppTheme.Colors.tabUnselected)
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
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .task(id: ownerProfileID) {
                await reloadOwnerTags()
            }
        }
        .diveActivityTagsSheetPresentation()
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
