import SwiftUI

/// Avatar-first trip buddy grid cell — top-aligned within **`LazyVGrid`** rows so profile images line up.
struct TripDetailBuddyAvatarGridCell: View {
    let profilePhoto: Data?
    let displayName: String
    /// Accent label under the name (e.g. **You**). Empty hides the row.
    var subtitle: String = ""
    var showsGoDiveUserPin: Bool = false
    /// Cert-style capsule (**Invited** / **Joined**).
    var statusBadgeTitle: String? = nil
    /// When set, shows a tappable **Invite** capsule instead of a status badge.
    var inviteAction: (() -> Void)? = nil
    /// When false, only avatar + name render (status sits outside a **`NavigationLink`** label).
    var showsStatusRow: Bool = true

    private var avatarDiameter: CGFloat { TripDetailBuddiesPresentation.avatarDiameter }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            ProfileAvatarView(
                profilePhoto: profilePhoto,
                diameter: avatarDiameter,
                iconFont: .title2,
                placeholderInitials: DiveBuddyPresentation.initials(from: displayName)
            )
            .goDiveUserAvatarPin(shows: showsGoDiveUserPin, avatarDiameter: avatarDiameter)

            tripBuddyNameCaption

            if showsStatusRow {
                TripBuddyStatusChrome(
                    subtitle: subtitle,
                    statusBadgeTitle: statusBadgeTitle,
                    inviteAction: inviteAction
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// First name(s) on line 1, last name on line 2 (last whitespace token).
    private var tripBuddyNameCaption: some View {
        let lines = DiveBuddyPresentation.twoLineDisplayName(from: displayName)
        return VStack(spacing: 0) {
            Text(lines.firstLine)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            if let secondLine = lines.secondLine {
                Text(secondLine)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: TripDetailBuddiesPresentation.gridCaptionMinHeight,
            alignment: .top
        )
    }
}

/// Compact status row (You / Invited / Joined / Invite) under a buddy avatar.
struct TripBuddyStatusChrome: View {
    var subtitle: String = ""
    var statusBadgeTitle: String? = nil
    var inviteAction: (() -> Void)? = nil

    private var trimmedSubtitle: String {
        subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            if let inviteAction {
                Button(action: inviteAction) {
                    Text(TripDetailPlannedBuddyPresentation.inviteButtonTitle)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background {
                            Capsule()
                                .strokeBorder(AppTheme.Colors.accent.opacity(0.55), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("TripDetail.Buddies.InviteButton")
            } else if let statusBadgeTitle, !statusBadgeTitle.isEmpty {
                TripBuddyStatusBadge(title: statusBadgeTitle)
            }

            if !trimmedSubtitle.isEmpty {
                Text(trimmedSubtitle)
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
        }
    }
}
