import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Picker sheet: non-retired locker gear not yet on this dive.
struct DiveActivityAddEquipmentSheet: View {
    @Environment(\.dismiss) private var dismiss

    let items: [EquipmentItem]
    var onAdd: (EquipmentItem) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No gear to add",
                        systemImage: "archivebox",
                        description: Text("Everything in your locker is already on this dive, or all items are retired.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: AppTheme.Spacing.sm) {
                            ForEach(items, id: \.id) { item in
                                Button {
                                    onAdd(item)
                                } label: {
                                    DiveActivityAddEquipmentSheetRow(item: item)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("DiveAddEquipment.Row.\(item.id.uuidString)")
                            }
                        }
                        .padding(AppTheme.Spacing.md)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppGlassToolbarCancelButton(
                        action: { dismiss() },
                        accessibilityIdentifier: "DiveAddEquipment.Cancel"
                    )
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppGlassProminentDoneButton(
                        action: { dismiss() },
                        accessibilityIdentifier: "DiveAddEquipment.Done"
                    )
                }
            }
        }
        .diveActivityAddEquipmentSheetPresentation()
        .accessibilityIdentifier("DiveAddEquipment.Root")
    }
}

private struct DiveActivityAddEquipmentSheetRow: View {
    let item: EquipmentItem

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            rowThumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(EquipmentItemPresentation.title(for: item))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)

                Text(EquipmentItemPresentation.gearTypeLabel(for: item))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            Spacer(minLength: 0)

            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppTheme.Colors.tabSelected)
                .accessibilityHidden(true)
        }
        .padding(AppTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        )
    }

    @ViewBuilder
    private var rowThumbnail: some View {
        #if canImport(UIKit)
        if let data = item.equipmentPhoto, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
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
            .font(.body)
            .foregroundStyle(AppTheme.Colors.accent)
            .frame(width: 44, height: 44)
            .background(AppTheme.Colors.surfaceMuted.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
