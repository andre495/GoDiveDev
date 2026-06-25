import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Read-only equipment detail with **Edit** sheet.
struct ViewEquipmentDetails: View {
    @Bindable var item: EquipmentItem

    @State private var showsEditSheet = false
    @State private var headerClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback

    private var pageTitle: String {
        EquipmentItemPresentation.title(for: item)
    }

    var body: some View {
        AppHeaderlessPage {
            GeometryReader { proxy in
                let safeTop = AppScrollUnderHeaderListLayout.resolvedSafeAreaTop(proxy.safeAreaInsets.top)
                let topInset = AppScrollUnderHeaderListLayout.listTopInset(
                    safeAreaTop: safeTop,
                    headerClearance: headerClearance
                )

                ZStack(alignment: .top) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            heroImage(extraTopInset: safeTop)

                            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                                titleBlock
                                equipmentSection
                                flagsSection
                                purchaseSection
                                serviceSection
                                notesSection
                            }
                            .padding(AppTheme.Spacing.md)
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .ignoresSafeArea(edges: .top)

                    LogbookTopChromeScrim(topObstructionHeight: topInset)
                        .padding(.top, -safeTop)
                        .ignoresSafeArea(edges: .top)
                        .allowsHitTesting(false)
                        .zIndex(0.5)

                    Color.clear
                        .frame(height: topInset)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .contentShape(Rectangle())
                        .accessibilityHidden(true)
                        .zIndex(0.75)

                    AppHeader(
                        title: "",
                        showsBackButton: true,
                        showsBrandWordmark: false,
                        statusBarSafeAreaTop: safeTop
                    ) {
                        editToolbarButton
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .zIndex(1)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .onPreferenceChange(AppHeaderMetrics.HeightKey.self) { height in
                    if height > 0 { headerClearance = height }
                }
            }
        }
        .hidesBottomTabBarWhenPushed()
        .sheet(isPresented: $showsEditSheet) {
            EquipmentEditSheetView(item: item) {
                showsEditSheet = false
            }
        }
        .accessibilityIdentifier("EquipmentDetails.Root")
    }

    private var editToolbarButton: some View {
        AppEditToolbarButton(
            action: { showsEditSheet = true },
            accessibilityIdentifier: "EquipmentDetails.Edit"
        )
    }

    @ViewBuilder
    private func heroImage(extraTopInset: CGFloat) -> some View {
        let height = EquipmentItemPresentation.detailHeroBaseHeight + extraTopInset
        Group {
            #if canImport(UIKit)
            if let data = item.equipmentPhoto, let image = UIImage(data: data) {
                GeometryReader { proxy in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }
            } else {
                heroPlaceholder
            }
            #else
            heroPlaceholder
            #endif
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityLabel(
            item.equipmentPhoto == nil ? "Equipment photo placeholder" : "Equipment photo"
        )
    }

    private var heroPlaceholder: some View {
        Rectangle()
            .fill(AppTheme.Colors.tabUnselected.opacity(0.12))
            .overlay {
                Image(systemName: "archivebox.fill")
                    .font(.largeTitle)
                    .foregroundStyle(AppTheme.Colors.tabUnselected.opacity(0.55))
            }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(pageTitle)
                .font(.title.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text(EquipmentItemPresentation.gearTypeLabel(for: item))
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)

            if item.isRetired {
                Text("Retired")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
            }
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
