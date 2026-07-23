import SwiftUI
import SwiftData

/// Buddy roster detail, or **`FriendProfileView`** when the roster row is linked to a GoDive friend.
struct DiveBuddyOrFriendDetailView: View {
    let buddy: DiveBuddy

    var body: some View {
        if let edge = DiveBuddyFriendLinkPresentation.friendEdge(for: buddy) {
            FriendProfileView(friend: edge)
                .hidesBottomTabBarWhenPushed()
        } else {
            ViewDiveBuddyDetails(buddy: buddy)
                .hidesBottomTabBarWhenPushed()
        }
    }
}
