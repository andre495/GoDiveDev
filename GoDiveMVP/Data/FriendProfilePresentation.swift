import SwiftUI

enum FriendProfilePresentation: Sendable {
    /// Remote profile hero uses aspect-fill stills / video — clip overflow so media cannot paint past the hero band into the blue sheet (same contract as Buddy Feed heroes).
    nonisolated static let clipsOverflowingHeroMedia = true
}
