import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Off-screen share card — trip title, dates, map, stats callout, diver avatars, logo footer.
struct TripShareCardView: View {
    let tripTitle: String
    let dateRange: String
    let members: [TripShareCardMember]
    var marineLifeCallout: String?
    #if canImport(UIKit)
    var mapImage: UIImage?
    #endif

    private let columns = [
        GridItem(.adaptive(minimum: TripShareCardPresentation.avatarGridMinimum), spacing: AppTheme.Spacing.lg),
    ]

    private var mapSnapshotSize: CGSize {
        TripShareMapSnapshotPresentation.mapSnapshotSize(
            cardWidth: TripShareCardPresentation.cardWidth
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("GoDive")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.accent)
                    .textCase(.uppercase)

                Text(tripTitle)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(dateRange)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            #if canImport(UIKit)
            if let mapImage {
                Image(uiImage: mapImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: mapSnapshotSize.width, height: mapSnapshotSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.Colors.tabUnselected.opacity(0.14), lineWidth: 1)
                    }
                    .accessibilityLabel("Trip map")
            }
            #endif

            if let marineLifeCallout {
                marineLifeCalloutBadge(marineLifeCallout)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: AppTheme.Spacing.lg) {
                ForEach(members) { member in
                    VStack(spacing: AppTheme.Spacing.sm) {
                        ProfileAvatarView(
                            profilePhoto: member.profilePhoto,
                            diameter: TripShareCardPresentation.avatarDiameter,
                            iconFont: .title,
                            placeholderInitials: DiveBuddyPresentation.initials(from: member.displayName)
                        )

                        Text(member.displayName)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .frame(maxWidth: .infinity)

                        Text(member.subtitle)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(
                                member.usesAccentSubtitle
                                    ? AppTheme.Colors.accent
                                    : AppTheme.Colors.secondaryText
                            )
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Spacer(minLength: AppTheme.Spacing.lg)

            Image(TripShareCardPresentation.logoImageName)
                .resizable()
                .scaledToFit()
                .frame(height: TripShareCardPresentation.logoHeight)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
        }
        .padding(TripShareCardPresentation.contentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: TripShareCardPresentation.cardMinHeight, alignment: .top)
    }

    private func marineLifeCalloutBadge(_ label: String) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "fish.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.accent)
                .accessibilityHidden(true)

            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background {
            Capsule()
                .fill(AppTheme.Colors.surfaceElevated)
                .overlay {
                    Capsule()
                        .stroke(AppTheme.Colors.tabUnselected.opacity(0.14), lineWidth: 1)
                }
        }
        .accessibilityLabel(label)
    }
}
