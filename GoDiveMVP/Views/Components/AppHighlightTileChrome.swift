import SwiftUI

/// Shared fill + stroke for logbook dive rows and stat / highlight tiles.
enum AppListTileCardChrome {
    static let fill = AppTheme.Colors.surfaceElevated
    static let stroke = AppTheme.Colors.tabUnselected.opacity(0.12)
    static let strokeWidth: CGFloat = 1
}

/// Stat / highlight tile chrome — matches **`LogbookActivityRow`** card fill in light and dark mode.
struct AppHighlightTileChrome: View {
    var cornerRadius: CGFloat = AppTheme.HighlightTile.cornerRadius

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(AppListTileCardChrome.fill)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        AppListTileCardChrome.stroke,
                        lineWidth: AppListTileCardChrome.strokeWidth
                    )
            }
    }
}

extension View {
    func appHighlightTileChrome(cornerRadius: CGFloat = AppTheme.HighlightTile.cornerRadius) -> some View {
        background {
            AppHighlightTileChrome(cornerRadius: cornerRadius)
        }
    }
}
