import SwiftUI

/// Trailing **+** for Field Guide species search chrome (hub + browse).
struct FieldGuideMarineLifeAddToolbarButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: FieldGuideMarineLifeAddPresentation.chromeSystemImage)
                .font(.title3.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(FieldGuideMarineLifeAddPresentation.chromeAccessibilityLabel)
        .accessibilityIdentifier(FieldGuideMarineLifeAddPresentation.chromeAccessibilityIdentifier)
    }
}
