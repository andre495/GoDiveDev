import SwiftUI

/// Cert-style capsule for trip-share status (**Invited** / **Joined**).
struct TripBuddyStatusBadge: View {
    let title: String

    var body: some View {
        let style = TripDetailPlannedBuddyPresentation.statusBadgeStyle(title: title)
        Text(style.label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(style.foreground)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background {
                Capsule()
                    .fill(style.background)
            }
            .accessibilityLabel(style.label)
            .accessibilityIdentifier("TripDetail.Buddies.StatusBadge.\(title)")
    }
}
