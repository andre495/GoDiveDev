import SwiftUI

struct ConnectDeviceComingSoonView: View {
    var body: some View {
        AppPage(title: LogbookAddActivityPresentation.connectDevicePageTitle, showsBackButton: true) {
            VStack {
                Spacer(minLength: 0)
                AppComingSoonPlaceholder(
                    systemImage: "applewatch.radiowaves.left.and.right",
                    message: LogbookAddActivityPresentation.connectDeviceComingSoonMessage
                )
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityIdentifier("Logbook.ConnectDeviceComingSoon.Root")
    }
}
