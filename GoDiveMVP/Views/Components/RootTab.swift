import Foundation

/// Root **`TabView`** destinations (**`ContentView`**).
enum RootTab: Hashable, Sendable {
    case home
    case logbook
    case fieldGuide
    case explore
    case search
}

enum RootTabIndex {
    static let home = 0
    static let logbook = 1
    static let fieldGuide = 2
    static let explore = 3
}
