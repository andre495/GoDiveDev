import SwiftUI

/// **Buddies** overview card — horizontal avatars (add via section header **+**).
struct DiveActivityBuddiesOverviewSection: View {
    @Bindable var activity: DiveActivity

    var body: some View {
        buddiesContent
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
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
