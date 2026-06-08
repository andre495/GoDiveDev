import Contacts
import SwiftData
import SwiftUI

/// Tag **`DiveBuddy`** roster rows on this dive — roster picker + **+** to create a new buddy.
struct DiveActivityBuddiesEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession

    @Bindable var activity: DiveActivity

    @Query(sort: [SortDescriptor(\DiveBuddy.displayName, order: .forward)])
    private var allBuddies: [DiveBuddy]

    @State private var showsAddBuddySheet = false

    private var ownerProfileID: UUID? {
        accountSession.currentProfile?.id
    }

    private var ownedBuddies: [DiveBuddy] {
        guard let ownerProfileID else { return [] }
        return allBuddies.filter { $0.ownerProfileID == ownerProfileID }
    }

    var body: some View {
        NavigationStack {
            List {
                if ownedBuddies.isEmpty {
                    Section {
                        Text("No buddies in your roster yet. Tap + to add someone and tag them on this dive.")
                            .font(.body)
                            .foregroundStyle(AppTheme.Colors.tabUnselected)
                            .accessibilityIdentifier("DiveBuddiesEditSheet.EmptyRoster")
                    }
                } else {
                    Section {
                        ForEach(ownedBuddies, id: \.id) { buddy in
                            Button {
                                toggleBuddyOnDive(buddy)
                            } label: {
                                DiveActivityBuddyRosterPickerRow(
                                    buddy: buddy,
                                    isTaggedOnDive: isBuddyTaggedOnDive(buddy)
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
                                isBuddyTaggedOnDive(buddy) ? "Tagged on this dive" : "Not on this dive"
                            )
                            .accessibilityIdentifier("DiveBuddiesEditSheet.RosterRow.\(buddy.id.uuidString)")
                        }
                    } header: {
                        Text("Your buddies")
                    } footer: {
                        Text("Tap a buddy to tag or remove them on this dive.")
                    }
                }
            }
            .listStyle(.plain)
            .listRowSpacing(DiveActivityBuddyRosterPickerRowLayout.listRowSpacing)
            .scrollContentBackground(.hidden)
            .navigationTitle("Buddies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showsAddBuddySheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.tabSelected)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add buddy")
                    .accessibilityIdentifier("DiveBuddiesEditSheet.AddBuddy")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.Colors.tabSelected)
                    .accessibilityIdentifier("DiveBuddiesEditSheet.Done")
                }
            }
        }
        .diveActivityTagsSheetPresentation()
        .sheet(isPresented: $showsAddBuddySheet) {
            DiveActivityAddBuddySheet(activity: activity)
        }
        .accessibilityIdentifier("DiveBuddiesEditSheet.Root")
    }

    private func isBuddyTaggedOnDive(_ buddy: DiveBuddy) -> Bool {
        DiveBuddyActivityAssociation.isBuddyTagged(buddyID: buddy.id, on: activity)
    }

    private func toggleBuddyOnDive(_ buddy: DiveBuddy) {
        if isBuddyTaggedOnDive(buddy) {
            guard let tag = activity.buddies.first(where: { $0.buddyID == buddy.id }) else { return }
            DiveBuddyActivityAssociation.removeTag(tag, from: activity, modelContext: modelContext)
        } else {
            DiveBuddyActivityAssociation.tagBuddy(buddy, on: activity, modelContext: modelContext)
        }
    }
}

// MARK: - Roster row

private enum DiveActivityBuddyRosterPickerRowLayout {
    static let avatarDiameter: CGFloat = 36
    static let rowPadding = EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
    static let listRowSpacing: CGFloat = 6
    static let cornerRadius: CGFloat = 10
}

private struct DiveActivityBuddyRosterPickerRow: View {
    let buddy: DiveBuddy
    let isTaggedOnDive: Bool

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ProfileAvatarView(
                profilePhoto: buddy.profilePhoto,
                diameter: DiveActivityBuddyRosterPickerRowLayout.avatarDiameter,
                iconFont: .callout
            )

            Text(buddy.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isTaggedOnDive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.tabSelected)
                    .accessibilityHidden(true)
            }
        }
        .padding(DiveActivityBuddyRosterPickerRowLayout.rowPadding)
        .background(rowBackground)
        .accessibilityElement(children: .combine)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: DiveActivityBuddyRosterPickerRowLayout.cornerRadius, style: .continuous)
            .fill(
                isTaggedOnDive
                    ? AppTheme.Colors.tabSelected.opacity(0.14)
                    : AppTheme.Colors.surfaceElevated
            )
            .overlay {
                RoundedRectangle(cornerRadius: DiveActivityBuddyRosterPickerRowLayout.cornerRadius, style: .continuous)
                    .stroke(
                        isTaggedOnDive ? AppTheme.Colors.tabSelected.opacity(0.55) : Color.clear,
                        lineWidth: 1.5
                    )
            }
    }
}
