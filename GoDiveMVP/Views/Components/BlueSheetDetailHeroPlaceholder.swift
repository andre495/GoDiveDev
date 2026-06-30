import SwiftUI

/// Muted hero band when pushed detail pages have no media or map yet.
struct BlueSheetDetailHeroPlaceholder: View {
    let systemImage: String
    let accessibilityLabel: String

    init(style: PushedDetailHeroHeaderView.Style) {
        systemImage = style.emptyPlaceholderSystemImage
        accessibilityLabel = style.emptyPlaceholderAccessibilityLabel
    }

    init(systemImage: String, accessibilityLabel: String) {
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel
    }

    var body: some View {
        Rectangle()
            .fill(AppTheme.Colors.tabUnselected.opacity(BlueSheetDetailHeroPresentation.placeholderFillOpacity))
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: BlueSheetDetailHeroPresentation.placeholderIconSize))
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel(accessibilityLabel)
    }
}

/// Short muted band while deferred hero content (map / tagged media) mounts.
struct BlueSheetDetailHeroLoadingBand: View {
    var accessibilityLabel: String = "Loading hero content"

    var body: some View {
        AppTheme.Colors.surfaceMuted
            .opacity(BlueSheetDetailHeroPresentation.loadingBandOpacity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel(accessibilityLabel)
    }
}
