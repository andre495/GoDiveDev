import SwiftData
import SwiftUI

/// Owner **`DiveBuddy`** roster — pushed from **Profile**.
struct DiveBuddiesListView: View {
    @Environment(AccountSession.self) private var accountSession

    @Query private var ownedBuddies: [DiveBuddy]

    @State private var showsAddBuddySheet = false

    init(ownerProfileID: UUID? = nil) {
        let filterOwnerID = ownerProfileID ?? Self.noOwnerQueryToken
        _ownedBuddies = Query(
            filter: #Predicate<DiveBuddy> { $0.ownerProfileID == filterOwnerID },
            sort: [SortDescriptor(\DiveBuddy.displayName, order: .forward)]
        )
    }

    private static let noOwnerQueryToken = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private var ownerProfileID: UUID? {
        accountSession.currentProfile?.id
    }

    private var rosterBuddies: [DiveBuddy] {
        DiveBuddySelfRepresentation.rosterBuddiesExcludingSelf(
            ownedBuddies,
            owner: accountSession.currentProfile
        )
    }

    var body: some View {
        AppPage(
            title: "Dive Buddies",
            showsBackButton: true,
            showsBrandWordmark: false,
            scrollContentUnderHeader: true,
            collapsibleInlineTitleHeader: true,
            showsWaterBubbleBackground: true,
            trailingContent: {
                addBuddyToolbarButton
            }
        ) {
            if rosterBuddies.isEmpty {
                AppScrollUnderHeaderEmptyState {
                    emptyState
                }
            } else {
                buddyList
            }
        }
        .hidesBottomTabBarWhenPushed()
        .sheet(isPresented: $showsAddBuddySheet) {
            DiveActivityAddBuddySheet()
        }
        .accessibilityIdentifier("DiveBuddiesList.Root")
    }

    private var addBuddyToolbarButton: some View {
        Button {
            showsAddBuddySheet = true
        } label: {
            Image(systemName: "plus")
                .appToolbarIconButtonLabel()
        }
        .appStandaloneIconButtonStyle()
        .accessibilityLabel("Add buddy")
        .accessibilityIdentifier("DiveBuddiesList.AddNewBuddy")
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "person.2")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.Colors.accent.opacity(0.85))

            Text("No dive buddies yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text("Tap + to add a buddy, or tag buddies on a dive from the dive overview.")
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.lg)
        .accessibilityIdentifier("DiveBuddiesList.EmptyState")
    }

    private var buddyList: some View {
        AppScrollUnderHeaderList(listAccessibilityIdentifier: "DiveBuddiesList.List") {
            ForEach(rosterBuddies, id: \.id) { buddy in
                NavigationLink {
                    ViewDiveBuddyDetails(buddy: buddy)
                        .hidesBottomTabBarWhenPushed()
                } label: {
                    DiveBuddyListRowView(
                        buddy: buddy,
                        sharedDiveCount: sharedDiveCount(for: buddy)
                    )
                }
                .buttonStyle(.plain)
                .navigationLinkIndicatorVisibility(.hidden)
                .listRowInsets(AppScrollUnderHeaderListLayout.horizontalRowInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
    }

    private func sharedDiveCount(for buddy: DiveBuddy) -> Int {
        guard let ownerProfileID else { return 0 }
        return DiveBuddyRosterPresentation.sharedDiveCount(for: buddy, ownerProfileID: ownerProfileID)
    }
}

// MARK: - Row

private struct DiveBuddyListRowView: View {
    let buddy: DiveBuddy
    let sharedDiveCount: Int

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            ProfileAvatarView(
                profilePhoto: buddy.profilePhoto,
                diameter: 48,
                iconFont: .title3,
                placeholderInitials: DiveBuddyPresentation.initials(from: buddy.displayName)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(buddy.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)

                Text(DiveBuddyRosterPresentation.listSubtitle(sharedDiveCount: sharedDiveCount))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(AppTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(buddy.displayName), \(DiveBuddyRosterPresentation.listSubtitle(sharedDiveCount: sharedDiveCount))")
    }
}
