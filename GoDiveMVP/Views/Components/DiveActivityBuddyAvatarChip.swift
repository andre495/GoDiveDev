import SwiftUI

/// Avatar with first-name caption for a dive buddy on overview / details.
struct DiveActivityBuddyAvatarChip: View {
    let displayName: String
    let profilePhoto: Data?
    var avatarDiameter: CGFloat = 56

    private var firstName: String {
        DiveBuddyPresentation.firstName(from: displayName)
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            ProfileAvatarView(
                profilePhoto: profilePhoto,
                diameter: avatarDiameter,
                iconFont: .title3,
                placeholderInitials: DiveBuddyPresentation.initials(from: displayName)
            )
            Text(firstName)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: max(avatarDiameter, 52))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(displayName)
    }
}
