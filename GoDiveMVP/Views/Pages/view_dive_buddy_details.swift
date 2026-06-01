import SwiftData
import SwiftUI

/// Buddy roster detail — pushed (not a sheet) from **`DiveBuddiesListView`**.
struct ViewDiveBuddyDetails: View {
    @Environment(AccountSession.self) private var accountSession
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem

    @AppStorage(AppUserSettings.automaticallyRenumberDivesKey) private var automaticallyRenumberDives = true

    @Bindable var buddy: DiveBuddy

    @Query(sort: [SortDescriptor(\DiveActivity.startTime, order: .reverse)])
    private var allDiveActivities: [DiveActivity]

    @State private var showsEditSheet = false

    private var ownerProfileID: UUID? {
        accountSession.currentProfile?.id
    }

    private var sharedDives: [DiveActivity] {
        guard let ownerProfileID else { return [] }
        return DiveBuddyRosterPresentation.sharedDiveActivities(for: buddy, ownerProfileID: ownerProfileID)
    }

    private var sharedDiveCount: Int {
        sharedDives.count
    }

    private var diveRows: [DiveLogbookRowDisplayData] {
        DiveLogbookDisplay.rowData(
            activities: sharedDives,
            unitSystem: diveDisplayUnitSystem,
            duplicateIds: [],
            useChronologicalNumbers: automaticallyRenumberDives,
            numberingActivities: ownedDiveActivitiesForNumbering
        )
    }

    private var ownedDiveActivitiesForNumbering: [DiveActivity] {
        guard let ownerProfileID else { return [] }
        return allDiveActivities.filter { $0.ownerProfileID == ownerProfileID }
    }

    var body: some View {
        AppPage(
            title: buddy.displayName,
            showsBackButton: true,
            trailingContent: {
                Button("Edit") {
                    showsEditSheet = true
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabSelected)
                .accessibilityIdentifier("DiveBuddyDetails.Edit")
            },
            content: {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                        headerSection
                        divesTogetherSection
                    }
                    .padding(AppTheme.Spacing.md)
                }
            }
        )
        .hidesBottomTabBarWhenPushed()
        .sheet(isPresented: $showsEditSheet) {
            DiveBuddyEditSheetView(buddy: buddy) {
                showsEditSheet = false
            }
        }
        .accessibilityIdentifier("DiveBuddyDetails.Root")
    }

    private var headerSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ProfileAvatarView(
                profilePhoto: buddy.profilePhoto,
                diameter: 120,
                iconFont: .system(size: 56)
            )

            Text(buddy.displayName)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Text(DiveBuddyRosterPresentation.sharedDiveCountLabel(sharedDiveCount))
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("DiveBuddyDetails.Header")
    }

    @ViewBuilder
    private var divesTogetherSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Dives together")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            if diveRows.isEmpty {
                Text("No dives tagged with this buddy yet.")
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("DiveBuddyDetails.EmptyDives")
            } else {
                VStack(spacing: AppTheme.Spacing.md) {
                    ForEach(diveRows) { row in
                        if let activity = sharedDives.first(where: { $0.id == row.id }) {
                            NavigationLink {
                                ViewSingleActivity(activity: activity)
                            } label: {
                                LogbookActivityRow(data: row)
                            }
                            .buttonStyle(.plain)
                            .navigationLinkIndicatorVisibility(.hidden)
                        }
                    }
                }
                .accessibilityIdentifier("DiveBuddyDetails.DiveList")
            }
        }
    }
}
