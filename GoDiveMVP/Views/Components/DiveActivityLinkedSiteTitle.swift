import SwiftUI

/// Dive overview site name — tappable when linked to a catalog **`DiveSite`**.
struct DiveActivityLinkedSiteTitle: View {
    let title: String
    let linkedCatalogSiteID: UUID?
    var font: Font = .title2.weight(.bold)
    var lineLimit: Int? = 3
    var onOpenLinkedSite: (() -> Void)?

    private var isLinked: Bool {
        DiveActivityOverviewPresentation.siteTitleLinksToCatalogOverview(
            linkedCatalogSiteID: linkedCatalogSiteID
        )
    }

    var body: some View {
        Group {
            if isLinked, let onOpenLinkedSite {
                Button(action: onOpenLinkedSite) {
                    titleLabel
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens dive site overview")
                .accessibilityIdentifier("DiveOverview.LinkedSiteTitle")
            } else {
                titleLabel
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var titleLabel: some View {
        Text(title)
            .font(font)
            .foregroundStyle(isLinked ? AppTheme.Colors.linkedSiteTitleAccent : AppTheme.Colors.textPrimary)
            .multilineTextAlignment(.leading)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
