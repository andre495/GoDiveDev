import SwiftUI
import SwiftData

/// Buddies + marine life sections on the snorkel map overview sheet (matches dive map-tab tagging).
struct SnorkelActivityMapTaggingSectionsView: View {
    @Bindable var activity: SnorkelActivity
    let onManageBuddies: () -> Void
    let onManageMarineLife: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            buddiesSection
            marineLifeSection
        }
        .accessibilityIdentifier("SnorkelOverview.MapTaggingSections")
    }

    private var buddiesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            sectionHeader(
                title: "Buddies",
                addAccessibilityLabel: "Add buddies",
                sectionID: "buddies",
                onAdd: onManageBuddies
            )

            SnorkelActivityBuddiesOverviewSection(activity: activity)
                .padding(AppTheme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.Colors.surfaceElevated)
                }
        }
    }

    private var marineLifeSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            sectionHeader(
                title: DiveActivityMarineLifeOverviewPresentation.sectionTitle,
                addAccessibilityLabel: "Add marine life",
                sectionID: "marineLife",
                onAdd: onManageMarineLife
            )

            SnorkelActivityMarineLifeOverviewSection(activity: activity)
                .padding(AppTheme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.Colors.surfaceElevated)
                }
        }
    }

    private func sectionHeader(
        title: String,
        addAccessibilityLabel: String,
        sectionID: String,
        onAdd: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabUnselected)

            Spacer(minLength: AppTheme.Spacing.sm)

            DiveActivitySectionHeaderActionButton(
                systemImage: "plus",
                accessibilityLabel: addAccessibilityLabel,
                action: onAdd
            )
            .accessibilityIdentifier("SnorkelOverview.Section.\(sectionID).Add")
        }
    }
}
