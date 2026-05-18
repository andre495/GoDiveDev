import SwiftUI

extension View {
    /// Standard GoDive sheet chrome: rounded top corners + frosted **`.thinMaterial`** background.
    /// Apply on any **`.sheet`** content after detent / drag-indicator modifiers (see **`.cursor/rules/swiftui-sheet-standard.mdc`**).
    func appSheetPresentationChrome() -> some View {
        presentationCornerRadius(AppTheme.Sheet.cornerRadius)
            .presentationBackground {
                Rectangle()
                    .fill(.thinMaterial)
                    .opacity(AppTheme.Sheet.backgroundMaterialOpacity)
                    .ignoresSafeArea(edges: .bottom)
            }
    }
}
