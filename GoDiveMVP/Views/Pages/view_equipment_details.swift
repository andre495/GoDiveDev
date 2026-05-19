import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Read-only equipment detail with **Edit** sheet.
struct ViewEquipmentDetails: View {
    @Bindable var item: EquipmentItem

    @State private var showsEditSheet = false

    private var pageTitle: String {
        EquipmentItemPresentation.title(for: item)
    }

    var body: some View {
        AppPage(title: pageTitle, showsBackButton: true, trailingContent: {
            Button("Edit") {
                showsEditSheet = true
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.tabSelected)
            .accessibilityIdentifier("EquipmentDetails.Edit")
        }, content: {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    photoHero
                    equipmentSection
                    flagsSection
                    purchaseSection
                    serviceSection
                    notesSection
                }
                .padding(AppTheme.Spacing.md)
            }
        })
        .hidesBottomTabBarWhenPushed()
        .sheet(isPresented: $showsEditSheet) {
            EquipmentEditSheetView(item: item) {
                showsEditSheet = false
            }
        }
        .accessibilityIdentifier("EquipmentDetails.Root")
    }

    @ViewBuilder
    private var photoHero: some View {
        #if canImport(UIKit)
        if let data = item.equipmentPhoto, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        #endif
    }

    private var equipmentSection: some View {
        detailSection(title: "Equipment") {
            detailRow(label: "Manufacturer", value: EquipmentItemPresentation.displayString(item.manufacturer))
            detailRow(label: "Model", value: EquipmentItemPresentation.displayString(item.model))
            detailRow(label: "Type", value: EquipmentItemPresentation.displayString(item.type))
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

#Preview {
    let container = try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
    let item = EquipmentItem(
        manufacturer: "Apeks",
        model: "XTX50",
        type: "Regulator",
        purchaseDate: .now,
        price: 899.99,
        nextServiceDate: .now,
        serviceRecurrenceDays: 365
    )
    return NavigationStack {
        ViewEquipmentDetails(item: item)
    }
    .modelContainer(container)
}
