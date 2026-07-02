import SwiftUI

/// Trailing **+** for Field Guide species search chrome (hub + browse).
struct FieldGuideMarineLifeAddToolbarButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: FieldGuideMarineLifeAddPresentation.chromeSystemImage)
                .appToolbarIconButtonLabel()
        }
        .appStandaloneIconButtonStyle()
        .appHeaderChromeIconForeground()
        .accessibilityLabel(FieldGuideMarineLifeAddPresentation.chromeAccessibilityLabel)
        .accessibilityIdentifier(FieldGuideMarineLifeAddPresentation.chromeAccessibilityIdentifier)
    }
}
