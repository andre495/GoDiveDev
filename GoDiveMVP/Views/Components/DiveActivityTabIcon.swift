import SwiftUI

extension DiveActivityTab {
    @ViewBuilder
    func tabIconImage(isSelected: Bool) -> some View {
        let color = isSelected ? AppTheme.Colors.tabSelected : AppTheme.Colors.tabUnselected

        if let asset = assetImageName {
            // **`Image(systemName:)`** sizes intrinsically. **`resizable` + `scaledToFit`** inside a wide
            // tab label would absorb **`maxWidth: .infinity`** and balloon — cap with **`fixedSize()`**.
            Image(asset)
                .resizable()
                .renderingMode(.template)
                .interpolation(.high)
                .scaledToFit()
                .frame(height: DiveActivityTabIcon.tabGlyphPointSize)
                .frame(maxWidth: DiveActivityTabIcon.templateAssetMaxWidth)
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

    /// **`ScubaTankTab`** (template) width cap so it doesn’t outgrow typical **22** pt SF Symbol glyphs.
    static let templateAssetMaxWidth: CGFloat = 26
}
