import SwiftUI

/// Small offline affordance when cloud / full-res media is unavailable (replaces retry error chrome).
struct OfflineMediaUnavailableIndicator: View {
    var font: Font = .title3

    var body: some View {
        Image(systemName: "wifi.slash")
            .font(font)
            .foregroundStyle(AppTheme.Colors.tabUnselected)
            .accessibilityLabel("No network connection")
            .accessibilityIdentifier("OfflineMedia.Unavailable")
    }
}
