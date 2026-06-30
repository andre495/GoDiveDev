import SwiftData
import SwiftUI

/// Equipment detail metadata sections (equipment, status, purchase, service, notes).
struct EquipmentDetailMetadataView: View {
    @Bindable var item: EquipmentItem

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            equipmentSection
            flagsSection
            purchaseSection
            serviceSection
            notesSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var equipmentSection: some View {
        detailSection(title: "Equipment") {
            detailRow(label: "Manufacturer", value: EquipmentItemPresentation.displayString(item.manufacturer))
            detailRow(label: "Model", value: EquipmentItemPresentation.displayString(item.model))
            detailRow(
                label: "Gear type",
                value: EquipmentItemPresentation.gearTypeLabel(for: item)
            )
        }
    }

    private var flagsSection: some View {
        detailSection(title: "Status") {
            detailRow(
                label: "Dives used on",
                value: EquipmentItemPresentation.divesUsedOnLabel(
                    count: EquipmentItemPresentation.divesUsedOnCount(for: item)
                )
            )
            .accessibilityIdentifier("EquipmentDetails.DivesUsedOn")
            detailRow(label: "Retired", value: EquipmentItemPresentation.yesNo(item.isRetired))
            detailRow(label: "Auto-add on new dives", value: EquipmentItemPresentation.yesNo(item.autoAdd))
        }
    }

    private var purchaseSection: some View {
        detailSection(title: "Purchase") {
            detailRow(label: "Purchase date", value: EquipmentItemPresentation.formattedDate(item.purchaseDate))
            detailRow(label: "Shop", value: EquipmentItemPresentation.displayString(item.purchasedShop))
            detailRow(label: "Price", value: EquipmentItemPresentation.formattedPrice(item.price))
        }
    }

    private var serviceSection: some View {
        detailSection(title: "Service") {
            detailRow(label: "Next service", value: EquipmentItemPresentation.formattedDate(item.nextServiceDate))
            detailRow(label: "Last service", value: EquipmentItemPresentation.formattedDate(item.serviceDate))
            detailRow(
                label: "Recurrence",
                value: EquipmentItemPresentation.formattedRecurrence(days: item.serviceRecurrenceDays)
            )
            detailRow(label: "Service notes", value: EquipmentItemPresentation.displayString(item.serviceNotes))
        }
    }

    private var notesSection: some View {
        detailSection(title: "Notes") {
            detailRow(label: "Notes", value: EquipmentItemPresentation.displayString(item.notes))
        }
    }

    private func detailSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                content()
            }
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.Colors.surfaceElevated)
            )
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
            Text(value)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
