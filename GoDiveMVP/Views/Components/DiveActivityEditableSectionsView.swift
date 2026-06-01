import SwiftUI

/// Grouped tap-to-edit field rows for the map or tank overview panel.
struct DiveActivityEditableSectionsView: View {
    @Bindable var activity: DiveActivity
    let tab: DiveActivityEditablePanelTab
    let displayUnits: DiveDisplayUnitSystem
    let profileGasStats: DiveActivityTankPanelSummary.ProfilePressureStats
    let onEditField: (DiveActivityEditableFieldID) -> Void
    let onManageEquipment: () -> Void
    let onManageLinkedSite: () -> Void
    let onManageBuddies: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Tap any value with a chevron to edit.")
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.tabUnselected)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("DiveOverview.EditableHint")

            ForEach(DiveActivityEditableCatalog.sections(for: tab)) { section in
                sectionView(section)
            }
        }
        .accessibilityIdentifier(tab == .map ? "DiveOverview.MapEditableSections" : "DiveOverview.TankEditableSections")
    }

    @ViewBuilder
    private func sectionView(_ section: DiveActivityEditableCatalog.Section) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(section.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabUnselected)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                if section.id == "buddies" {
                    DiveActivityBuddiesOverviewSection(
                        activity: activity,
                        onManage: onManageBuddies
                    )
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

    private func row(for fieldID: DiveActivityEditableFieldID) -> some View {
        let editable = DiveActivityEditableCatalog.isEditable(fieldID)
        return DiveActivityEditableRow(
            label: DiveActivityEditableCatalog.label(for: fieldID),
            value: DiveActivityFieldEditing.displayValue(
                for: fieldID,
                activity: activity,
                displayUnits: displayUnits,
                profileGasStats: profileGasStats
            ),
            signaturePreviewData: fieldID == .diveSignature ? activity.diveSignatureData : nil,
            isEditable: editable || usesSpecialAction(fieldID),
            action: { performAction(for: fieldID) }
        )
        .accessibilityIdentifier("DiveOverview.Field.\(fieldID.rawValue)")
    }

    private func usesSpecialAction(_ fieldID: DiveActivityEditableFieldID) -> Bool {
        switch fieldID {
        case .linkedEquipment, .linkedCatalogSite, .buddies:
            return true
        default:
            return false
        }
    }

    private func performAction(for fieldID: DiveActivityEditableFieldID) {
        switch fieldID {
        case .linkedEquipment:
            onManageEquipment()
        case .linkedCatalogSite:
            onManageLinkedSite()
        case .buddies:
            onManageBuddies()
        default:
            if DiveActivityEditableCatalog.isEditable(fieldID) {
                onEditField(fieldID)
            }
        }
    }
}
