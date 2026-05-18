import SwiftUI

extension DiveActivityTab {
    @ViewBuilder
    func tabIconImage(isSelected: Bool) -> some View {
        let color = isSelected ? AppTheme.Colors.tabSelected : AppTheme.Colors.tabUnselected

        if let asset = assetImageName {
            let glyphSize = DiveActivityTabIcon.templateAssetSize(for: asset)
            Image(asset)
                .renderingMode(.template)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: glyphSize.width, height: glyphSize.height)
                .foregroundStyle(color)
                .fixedSize()
        } else if let system = systemImageName {
            Image(systemName: system)
                .font(.system(size: DiveActivityTabIcon.tabGlyphPointSize, weight: .semibold))
                .foregroundStyle(color)
                .fixedSize()
        }
    }
}

enum DiveActivityTabIcon {
    static let menuRowHeight: CGFloat = 48

    /// Matches **`Image(systemName:)`** with **`.font(.system(size:weight:))`**.
    static let tabGlyphPointSize: CGFloat = 22

    /// Trimmed **`ScubaTankTab.png`** pixel width ÷ height (must match asset catalog art).
    static let scubaTankTabAspectWidthOverHeight: CGFloat = 35 / 72

    /// Tab-bar frame for a template asset at **`tabGlyphPointSize`** height.
    static func templateAssetSize(for assetName: String) -> CGSize {
        switch assetName {
        case "ScubaTankTab":
            let height = tabGlyphPointSize
            return CGSize(
                width: height * scubaTankTabAspectWidthOverHeight,
                height: height
            )
        default:
            let side = tabGlyphPointSize
            return CGSize(width: side, height: side)
        }
    }
}
