import SwiftUI

/// Invisible stand-in when a pushed activity is gone — pops immediately instead of a “no longer in your log” page.
struct ActivityMissingDestinationPopView: View {
    let onAppearPop: () -> Void

    var body: some View {
        AppTheme.Colors.screenBackgroundGradient
            .ignoresSafeArea()
            .accessibilityHidden(true)
            .onAppear(perform: onAppearPop)
    }
}
