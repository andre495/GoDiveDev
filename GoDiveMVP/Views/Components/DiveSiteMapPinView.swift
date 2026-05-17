import SwiftUI

/// Minimal dive-site indicator for MapKit (replaces the default **`Marker`** balloon pin).
struct DiveSiteMapPinView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 16, height: 16)
                .shadow(color: .black.opacity(0.18), radius: 2, y: 1)

            Circle()
                .fill(AppTheme.Colors.accentDeep)
                .frame(width: 10, height: 10)
        }
        .accessibilityHidden(true)
    }
}
