import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Create and manage **`EquipmentItem`** rows for the signed-in profile.
///
/// Pushed from **Profile** on Home’s **`NavigationStack`** — use destination-style row links (not a nested stack) so **Back** pops one level at a time.
struct EquipmentLockerView: View {
    @Environment(AccountSession.self) private var accountSession
    @Environment(\.modelContext) private var modelContext

    @Query(
        sort: [
            SortDescriptor(\EquipmentItem.manufacturer, order: .forward),
            SortDescriptor(\EquipmentItem.model, order: .forward),
        ]
    )
    private var allEquipment: [EquipmentItem]

    @State private var showsAddEquipmentSheet = false
    @State private var equipmentPendingDeletion: EquipmentItem?
    @State private var optimisticallyRemovedEquipmentIDs: Set<UUID> = []

    private var ownedEquipment: [EquipmentItem] {
        guard let ownerID = accountSession.currentProfile?.id else { return [] }
        return allEquipment.filter {
            $0.ownerProfileID == ownerID && !optimisticallyRemovedEquipmentIDs.contains($0.id)
        }
    }

    var body: some View {
        ZStack {
            AppPage(
                title: "Equipment Locker",
                showsBackButton: true,
                scrollContentUnderHeader: true,
                trailingContent: {
                addEquipmentToolbarButton
            }, content: {
                if ownedEquipment.isEmpty {
                    AppScrollUnderHeaderEmptyState {
                        emptyLockerState
                    }
                } else {
                    equipmentList
                }
            })

            if equipmentPendingDeletion != nil {
                deleteFlowOverlay
            }
        }
        .hidesBottomTabBarWhenPushed()
        .sheet(isPresented: $showsAddEquipmentSheet) {
            EquipmentAddSheetView {
                showsAddEquipmentSheet = false
            }
        }
    }

    private var addEquipmentToolbarButton: some View {
        Button {
            showsAddEquipmentSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add equipment")
        .accessibilityIdentifier("EquipmentLocker.AddNewEquipment")
    }

    private var emptyLockerState: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "archivebox")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.Colors.accent.opacity(0.85))

            Text("No equipment yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text("Tap + in the corner to log your first item.")
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.lg)
        .accessibilityIdentifier("EquipmentLocker.EmptyState")
    }

    private var equipmentList: some View {
        AppScrollUnderHeaderList(listAccessibilityIdentifier: "EquipmentLocker.List") {
            ForEach(ownedEquipment, id: \.id) { item in
                NavigationLink {
                    ViewEquipmentDetails(item: item)
                } label: {
                    EquipmentLockerRowView(item: item)
                }
                .buttonStyle(.plain)
                .navigationLinkIndicatorVisibility(.hidden)
                .listRowInsets(AppScrollUnderHeaderListLayout.horizontalRowInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        equipmentPendingDeletion = item
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var deleteFlowOverlay: some View {
        Group {
            if let item = equipmentPendingDeletion {
                confirmDeleteEquipmentOverlay(item: item)
            }
        }
    }

    private func confirmDeleteEquipmentOverlay(item: EquipmentItem) -> some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.16)) {
                        equipmentPendingDeletion = nil
                    }
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text("Delete equipment?")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("Are you sure? This cannot be undone.")
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .center) {
                    Button("Cancel") {
                        withAnimation(.easeOut(duration: 0.16)) {
                            equipmentPendingDeletion = nil
                        }
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.tabSelected)
                    .buttonStyle(.plain)

                    Spacer(minLength: AppTheme.Spacing.lg)

                    Button("Delete") {
                        confirmDeleteEquipment(item)
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.red)
                    .buttonStyle(.plain)
                }
                .padding(.top, AppTheme.Spacing.sm)
            }
            .padding(AppTheme.Spacing.lg)
            .frame(maxWidth: 320, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.Colors.surfaceElevated)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.Colors.tabUnselected.opacity(0.15), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
            .accessibilityAddTraits(.isModal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("EquipmentLocker.DeleteConfirmation")
    }

    private func confirmDeleteEquipment(_ item: EquipmentItem) {
        let id = item.id
        dismissDeleteOverlayImmediately()
        optimisticallyRemovedEquipmentIDs.insert(id)
        Task(priority: .userInitiated) { @MainActor in
            await Task.yield()
            defer { optimisticallyRemovedEquipmentIDs.remove(id) }
            try? EquipmentItemDeletion.deletePermanently(item, modelContext: modelContext)
        }
    }

    private func dismissDeleteOverlayImmediately() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            equipmentPendingDeletion = nil
        }
    }
}

// MARK: - Row

private struct EquipmentLockerRowView: View {
    let item: EquipmentItem

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            rowThumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(itemTitle)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)

                if !item.type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(item.type)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                if item.isRetired {
                    Text("Retired")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(AppTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(itemTitle)
    }

    private var itemTitle: String {
        let manufacturer = item.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = item.model.trimmingCharacters(in: .whitespacesAndNewlines)
        if manufacturer.isEmpty { return model }
        if model.isEmpty { return manufacturer }
        return "\(manufacturer) \(model)"
    }

    @ViewBuilder
    private var rowThumbnail: some View {
        #if canImport(UIKit)
        if let data = item.equipmentPhoto, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            rowThumbnailPlaceholder
        }
        #else
        rowThumbnailPlaceholder
        #endif
    }

    private var rowThumbnailPlaceholder: some View {
        Image(systemName: "archivebox.fill")
            .font(.title3)
            .foregroundStyle(AppTheme.Colors.accent)
            .frame(width: 48, height: 48)
            .background(AppTheme.Colors.surfaceMuted.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        EquipmentLockerView()
    }
    .environment(AccountSession.shared)
    .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
