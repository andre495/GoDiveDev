import SwiftUI

extension View {
    /// Breathing room below the sheet grabber before the first content row (modal and embedded overview).
    func appSheetContentTopSpacing() -> some View {
        padding(.top, AppTheme.Sheet.contentTopSpacing)
    }

    /// Standard GoDive sheet chrome: top spacing, rounded corners, frosted **`.thinMaterial`** background.
    /// Apply on any **`.sheet`** content after detent / drag-indicator modifiers (see **`.cursor/rules/swiftui-sheet-standard.mdc`**).
    func appSheetPresentationChrome() -> some View {
        appSheetContentTopSpacing()
            .presentationCornerRadius(AppTheme.Sheet.cornerRadius)
            .presentationBackground {
                Rectangle()
                    .fill(.thinMaterial)
                    .opacity(AppTheme.Sheet.backgroundMaterialOpacity)
                    .ignoresSafeArea(edges: .bottom)
            }
    }
}
