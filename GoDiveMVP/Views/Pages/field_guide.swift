import SwiftUI

struct FieldGuideView: View {
    var body: some View {
        NavigationStack {
            AppHeaderlessPage {
                Spacer()
            }
        }
        .navigationInteractivePopGestureForHiddenNavBar()
    }
}

#Preview {
    FieldGuideView()
}
