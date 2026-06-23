import SwiftUI

/// Avatar-first trip buddy grid cell — top-aligned within **`LazyVGrid`** rows so profile images line up.
struct TripDetailBuddyAvatarGridCell: View {
    let profilePhoto: Data?
    let displayName: String
    let subtitle: String

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            ProfileAvatarView(
                profilePhoto: profilePhoto,
                diameter: TripDetailBuddiesPresentation.avatarDiameter,
                iconFont: .title2,
                placeholderInitials: DiveBuddyPresentation.initials(from: displayName)
            )

            Text(displayName)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(TripDetailBuddiesPresentation.nameLineLimit)
                .minimumScaleFactor(0.85)
                .frame(
                    maxWidth: .infinity,
                    minHeight: TripDetailBuddiesPresentation.gridCaptionMinHeight,
                    alignment: .top
                )

            Text(subtitle)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.accent)
                .multilineTextAlignment(.center)
                .lineLimit(TripDetailBuddiesPresentation.subtitleLineLimit)
                .minimumScaleFactor(0.85)
                .frame(
                    maxWidth: .infinity,
                    minHeight: TripDetailBuddiesPresentation.gridCaptionMinHeight,
                    alignment: .top
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
