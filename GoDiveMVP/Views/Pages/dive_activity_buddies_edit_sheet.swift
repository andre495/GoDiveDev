import SwiftData
import SwiftUI

/// Add, rename, or remove buddy tags on a dive.
struct DiveActivityBuddiesEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var activity: DiveActivity

    @State private var newBuddyName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Buddy name", text: $newBuddyName)
                            .textInputAutocapitalization(.words)
                        Button("Add") {
                            addBuddy()
                        }
                        .disabled(newBuddyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } header: {
                    Text("Add buddy")
                }

                Section("On this dive") {
                    if activity.buddies.isEmpty {
                        Text("No buddies yet.")
                            .foregroundStyle(AppTheme.Colors.tabUnselected)
                    } else {
                        ForEach(activity.buddies, id: \.id) { buddy in
                            TextField("Name", text: buddyNameBinding(buddy))
                                .textInputAutocapitalization(.words)
                        }
                        .onDelete(perform: deleteBuddies)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Buddies")
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
        }
        .diveActivityFieldSheetPresentation()
        .accessibilityIdentifier("DiveBuddiesEditSheet.Root")
    }

    private func buddyNameBinding(_ buddy: DiveBuddyTag) -> Binding<String> {
        Binding(
            get: { buddy.displayName },
            set: { buddy.displayName = String($0.prefix(80)) }
        )
    }

    private func addBuddy() {
        let trimmed = newBuddyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let tag = DiveBuddyTag(displayName: trimmed, dive: activity)
        modelContext.insert(tag)
        activity.buddies.append(tag)
        newBuddyName = ""
    }

    private func deleteBuddies(at offsets: IndexSet) {
        let sorted = activity.buddies
        for index in offsets {
            let buddy = sorted[index]
            modelContext.delete(buddy)
        }
        activity.buddies.remove(atOffsets: offsets)
    }
}
