import SwiftUI

extension DiveActivityOverviewDetent {
    var presentationDetent: PresentationDetent {
        .fraction(heightFraction)
    }

    static var allPresentationDetents: Set<PresentationDetent> {
        Set(allCases.map(\.presentationDetent))
    }

    init?(presentationDetent: PresentationDetent) {
        if let match = Self.allCases.first(where: { $0.presentationDetent == presentationDetent }) {
            self = match
        } else {
            return nil
        }
    }
}
