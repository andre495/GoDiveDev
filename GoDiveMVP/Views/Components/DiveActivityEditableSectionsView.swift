import SwiftUI

/// Grouped read-only field rows for the map or tank overview panel; edit per section via header actions.
struct DiveActivityEditableSectionsView: View {
    @Bindable var activity: DiveActivity
    let tab: DiveActivityEditablePanelTab
    let panelDetent: DiveActivityOverviewDetent
    let displayUnits: DiveDisplayUnitSystem
    let profileGasStats: DiveActivityTankPanelSummary.ProfilePressureStats
    let onEditSection: (DiveActivityEditableCatalog.Section) -> Void
    let onManageEquipment: () -> Void
    let onManageBuddies: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            ForEach(DiveActivityEditableCatalog.sections(for: tab, detent: panelDetent)) { section in
                sectionView(section)
            }
        }
        .accessibilityIdentifier(tab == .map ? "DiveOverview.MapEditableSections" : "DiveOverview.TankEditableSections")
    }

    @ViewBuilder
    private func sectionView(_ section: DiveActivityEditableCatalog.Section) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            sectionHeader(section)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                if section.id == "buddies" {
                    DiveActivityBuddiesOverviewSection(activity: activity)
                } else {
                    ForEach(section.fieldIDs, id: \.self) { fieldID in
                        row(for: fieldID)
                    }
                }
            }
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.Colors.surfaceElevated)
            }
        }
    }

    private func sectionHeader(_ section: DiveActivityEditableCatalog.Section) -> some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            Text(section.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabUnselected)

            Spacer(minLength: AppTheme.Spacing.sm)

            switch DiveActivityEditableCatalog.headerAction(for: section, activity: activity) {
            case .none:
                EmptyView()
            case .add:
                DiveActivitySectionHeaderActionButton(
                    systemImage: "plus",
                    accessibilityLabel: "Add buddies"
                ) {
                    onManageBuddies()
                }
                .accessibilityIdentifier("DiveOverview.Section.\(section.id).Add")
            case .editForm:
                DiveActivitySectionHeaderActionButton(
                    systemImage: "ellipsis",
                    accessibilityLabel: "Edit \(section.title)"
                ) {
                    onEditSection(section)
                }
                .accessibilityIdentifier("DiveOverview.Section.\(section.id).Edit")
            case .manageEquipment:
                DiveActivitySectionHeaderActionButton(
                    systemImage: "ellipsis",
                    accessibilityLabel: "Edit equipment"
                ) {
                    onManageEquipment()
                }
                .accessibilityIdentifier("DiveOverview.Section.\(section.id).Edit")
            }
        }
    }

    private func row(for fieldID: DiveActivityEditableFieldID) -> some View {
        DiveActivityEditableRow(
            label: DiveActivityEditableCatalog.label(for: fieldID),
            value: DiveActivityFieldEditing.displayValue(
                for: fieldID,
                activity: activity,
                displayUnits: displayUnits,
                profileGasStats: profileGasStats
            ),
            showsLabel: fieldID != .notes,
            signaturePreviewData: fieldID == .diveSignature ? activity.diveSignatureData : nil
        )
        .accessibilityIdentifier("DiveOverview.Field.\(fieldID.rawValue)")
    }
}
