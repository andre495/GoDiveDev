import SwiftData
import SwiftUI

/// Read-only equipment detail with **Edit** sheet (blue sheet + photo hero).
struct ViewEquipmentDetails: View {
    @Bindable var item: EquipmentItem

    @State private var showsEditSheet = false

    private var pageTitle: String {
        EquipmentItemPresentation.title(for: item)
    }

    var body: some View {
        BlueSheetDetailPage(
            configuration: .pushedDetail(
                accessibilityRootIdentifier: "EquipmentDetails.Root"
            ),
            hero: { _ in
                EquipmentDetailHeroBand(photoData: item.equipmentPhoto)
            },
            heroOverlay: { _ in EmptyView() },
            panelOverlay: { EmptyView() },
            pinnedContent: {
                equipmentPinnedSummary
            },
            panelContent: { bottomScrollInset, _ in
                EquipmentDetailContentPager(
                    item: item,
                    bottomScrollInset: bottomScrollInset
                )
            },
            topChrome: { safeTop, topInset, _ in
                BlueSheetDetailTopChrome(
                    safeTop: safeTop,
                    topInset: topInset,
                    onEdit: { showsEditSheet = true },
                    editAccessibilityIdentifier: "EquipmentDetails.Edit"
                )
            }
        )
        .sheet(isPresented: $showsEditSheet) {
            EquipmentEditSheetView(item: item) {
                showsEditSheet = false
            }
        }
    }

    private var equipmentPinnedSummary: some View {
        BlueSheetPinnedSummary(
            accent: item.isRetired ? "Retired" : nil,
            accentColor: AppTheme.Colors.tabUnselected,
            title: pageTitle,
            subtitle: EquipmentItemPresentation.gearTypeLabel(for: item),
            accessibilityIdentifier: "EquipmentDetails.TitleBlock"
        )
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
