import SwiftUI

/// Scuba vs snorkel identity row (symbol tint + optional dive **#** chip).
enum ActivityOverviewHeaderKind: Equatable {
    case scubaDive
    case snorkel
}

/// Map-tab overview sheet header — activity symbol (+ dive **#** for scuba), site, place, and start date/time.
struct DiveActivityMapOverviewHeader: View {
    var activityKind: ActivityOverviewHeaderKind = .scubaDive
    let diveNumberChip: String?
    let siteTitle: String
    let linkedCatalogSiteID: UUID?
    var onOpenLinkedSite: (() -> Void)?
    let regionCountryLine: String?
    let dateDashTimeLine: String
    /// When set, shows buddy avatar + name above the site title and moves activity identity to the site row.
    var sharedByDisplayName: String? = nil
    var sharedByPhotoURL: String? = nil
    /// Tap buddy avatar/name → friend profile (does not expand the overview sheet).
    var onOpenSharedBy: (() -> Void)? = nil
    /// Tap site / place / date (not the buddy row) — e.g. expand minimized overview.
    var onTapNonOwnerContent: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            if usesBuddyOwnerHeader {
                buddyOwnerRow
                nonOwnerContent
            } else {
                nonOwnerContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("DiveOverview.MapHeader")
    }

    private var nonOwnerContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            if usesBuddyOwnerHeader {
                siteTitleWithTrailingIdentity
            } else {
                if showsIdentityLeadingRow {
                    identityLeadingRow
                }

                DiveActivityLinkedSiteTitle(
                    title: siteTitle,
                    linkedCatalogSiteID: linkedCatalogSiteID,
                    onOpenLinkedSite: onOpenLinkedSite
                )
            }

            if let regionCountryLine, !regionCountryLine.isEmpty {
                Text(regionCountryLine)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.leading)
            }

            Text(dateDashTimeLine)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            onTapNonOwnerContent?()
        }
        .accessibilityElement(children: .combine)
    }

    private var usesBuddyOwnerHeader: Bool {
        DiveActivityMapOverviewHeaderPresentation.usesBuddyOwnerLayout(
            sharedByDisplayName: sharedByDisplayName
        )
    }

    private var showsIdentityLeadingRow: Bool {
        identityLeadingSymbolName != nil || diveNumberChip != nil
    }

    private var siteTitleWithTrailingIdentity: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            DiveActivityLinkedSiteTitle(
                title: siteTitle,
                linkedCatalogSiteID: linkedCatalogSiteID,
                onOpenLinkedSite: onOpenLinkedSite
            )

            if showsIdentityLeadingRow {
                identityTrailingCluster
            }
        }
    }

    @ViewBuilder
    private var buddyOwnerRow: some View {
        if let onOpenSharedBy {
            Button(action: onOpenSharedBy) {
                buddyOwnerRowLabel
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(buddyOwnerAccessibilityLabel)
            .accessibilityHint(
                DiveActivityMapOverviewHeaderPresentation.openFriendProfileAccessibilityHint
            )
        } else {
            buddyOwnerRowLabel
                .accessibilityElement(children: .combine)
                .accessibilityLabel(buddyOwnerAccessibilityLabel)
        }
    }

    private var buddyOwnerRowLabel: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            FriendSharedMapOwnerAvatarView(
                displayName: sharedByDisplayName ?? "",
                photoURL: sharedByPhotoURL,
                diameter: DiveActivityMapOverviewHeaderPresentation.buddyOwnerAvatarDiameter
            )

            Text(sharedByDisplayName ?? "")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private var buddyOwnerAccessibilityLabel: String {
        sharedByDisplayName.map {
            "\($0), \(GoDiveUserAvatarPinPresentation.accessibilityLabel)"
        } ?? GoDiveUserAvatarPinPresentation.accessibilityLabel
    }

    private var identityTrailingCluster: some View {
        HStack(spacing: 6) {
            if let identityLeadingSymbolName {
                Image(systemName: identityLeadingSymbolName)
                    .font(
                        .system(
                            size: DiveActivityOverviewPresentation.activityIdentitySymbolPointSize,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(identityLeadingSymbolColor)
                    .accessibilityHidden(true)
            }

            if let diveNumberChip {
                diveNumberChipLabel(diveNumberChip)
            }
        }
        .layoutPriority(0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(identityLeadingRowAccessibilityLabel)
    }

    private var identityLeadingSymbolName: String? {
        switch activityKind {
        case .scubaDive:
            LogbookActivityRowPresentation.scubaDiveLeadingSymbolName
        case .snorkel:
            LogbookActivityRowPresentation.snorkelLeadingSymbolName
        }
    }

    private var identityLeadingSymbolColor: Color {
        switch activityKind {
        case .scubaDive:
            AppTheme.Colors.accent
        case .snorkel:
            .red
        }
    }

    private var identityLeadingRow: some View {
        HStack(spacing: 6) {
            if let identityLeadingSymbolName {
                Image(systemName: identityLeadingSymbolName)
                    .font(
                        .system(
                            size: DiveActivityOverviewPresentation.activityIdentitySymbolPointSize,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(identityLeadingSymbolColor)
                    .accessibilityHidden(true)
            }

            if let diveNumberChip {
                diveNumberChipLabel(diveNumberChip)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(identityLeadingRowAccessibilityLabel)
    }

    private var identityLeadingRowAccessibilityLabel: String {
        switch activityKind {
        case .snorkel:
            "Snorkel activity"
        case .scubaDive:
            if let diveNumberChip {
                "Scuba dive number \(diveNumberChip)"
            } else {
                "Scuba dive"
            }
        }
    }

    private func diveNumberChipLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.accent)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background {
                Capsule(style: .continuous)
                    .strokeBorder(AppTheme.Colors.accent.opacity(0.55), lineWidth: 1)
                    .background {
                        Capsule(style: .continuous)
                            .fill(AppTheme.Colors.accent.opacity(0.1))
                    }
            }
            .accessibilityLabel("Dive number \(title)")
    }
}
