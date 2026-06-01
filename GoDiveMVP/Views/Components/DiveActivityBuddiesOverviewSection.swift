import SwiftUI

/// **Buddies** overview card — horizontal avatars + tap to manage.
struct DiveActivityBuddiesOverviewSection: View {
    @Bindable var activity: DiveActivity
    let onManage: () -> Void

    var body: some View {
        Button(action: onManage) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                buddiesContent
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Edit buddies")
        .accessibilityIdentifier("DiveOverview.BuddiesSection")
    }

    @ViewBuilder
    private var buddiesContent: some View {
        if activity.buddies.isEmpty {
            Text("—")
                .font(.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.md) {
                    ForEach(activity.buddies, id: \.id) { tag in
                        DiveActivityBuddyAvatarChip(
                            displayName: tag.displayName,
                            profilePhoto: tag.buddy?.profilePhoto
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var accessibilityLabel: String {
        if activity.buddies.isEmpty {
            return "Buddies, none"
        }
        let names = activity.buddies.map(\.displayName).joined(separator: ", ")
        return "Buddies, \(names)"
    }
}
