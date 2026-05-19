import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// **Tank** tab: gear linked to this dive + **+** picker for more locker items.
struct DiveActivityTankEquipmentSection: View {
    @Bindable var activity: DiveActivity

    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession

    @State private var showsAddEquipmentSheet = false
    @State private var linkErrorMessage: String?

    private var linkedItems: [EquipmentItem] {
        (try? DiveActivityEquipmentAssociation.linkedEquipment(on: activity, modelContext: modelContext)) ?? []
    }

    private var addableItems: [EquipmentItem] {
        guard let ownerID = accountSession.currentProfile?.id ?? activity.ownerProfileID else { return [] }
        return (
            try? DiveActivityEquipmentAssociation.addableEquipment(
                for: activity,
                ownerProfileID: ownerID,
                modelContext: modelContext
            )
        ) ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            equipmentSectionHeader

            if linkedItems.isEmpty {
                Text("No equipment on this dive yet.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppTheme.Spacing.md)
                    .background(sectionCardBackground)
                    .accessibilityIdentifier("DiveTankEquipment.Empty")
            } else {
                VStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(linkedItems, id: \.id) { item in
                        DiveActivityEquipmentRowView(item: item)
                            .accessibilityIdentifier("DiveTankEquipment.Row.\(item.id.uuidString)")
                    }
                }
            }
        }
        .sheet(isPresented: $showsAddEquipmentSheet) {
            DiveActivityAddEquipmentSheet(
                items: addableItems,
                onAdd: { item in
                    addEquipment(item)
                }
            )
        }
        .alert("Could not add equipment", isPresented: linkErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(linkErrorMessage ?? "Try again.")
        }
    }

    private var equipmentSectionHeader: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            Text("Equipment")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabUnselected)

            Spacer(minLength: 0)

            Button {
                showsAddEquipmentSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AppTheme.Colors.tabSelected)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add equipment")
            .accessibilityIdentifier("DiveTankEquipment.Add")
        }
    }

    private var sectionCardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppTheme.Colors.surfaceElevated)
    }

    private var linkErrorBinding: Binding<Bool> {
        Binding(
            get: { linkErrorMessage != nil },
            set: { if !$0 { linkErrorMessage = nil } }
        )
    }

    private func addEquipment(_ item: EquipmentItem) {
        do {
            try DiveActivityEquipmentAssociation.link(item, to: activity, modelContext: modelContext)
            try modelContext.save()
        } catch {
            linkErrorMessage = error.localizedDescription
        }
    }
}

// MARK: - Row

private struct DiveActivityEquipmentRowView: View {
    let item: EquipmentItem

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            rowThumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(EquipmentItemPresentation.title(for: item))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)

                if !item.type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(item.type)
                        .font(.subheadline)
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
        .accessibilityLabel(EquipmentItemPresentation.title(for: item))
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
