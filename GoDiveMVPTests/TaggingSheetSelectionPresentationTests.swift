import Foundation
import Testing
@testable import GoDiveMVP

struct TaggingSheetSelectionPresentationTests {

    @Test func lineLimits_matchNotificationStyleContract() {
        #expect(TaggingSheetSelectionPresentation.titleLineLimit == 1)
        #expect(TaggingSheetSelectionPresentation.subtitleLineLimit == 2)
        #expect(TaggingSheetSelectionPresentation.leadingArtDiameter == 44)
    }

    @Test func selectionSystemName_togglesGrayAndBlueCircles() {
        #expect(
            TaggingSheetSelectionPresentation.selectionSystemName(isSelected: false)
                == "circle"
        )
        #expect(
            TaggingSheetSelectionPresentation.selectionSystemName(isSelected: true)
                == "checkmark.circle.fill"
        )
    }

    @Test func dividerLeadingInset_matchesArtPlusSpacing() {
        #expect(TaggingSheetSelectionPresentation.dividerLeadingInset == 60.0)
    }

    @Test func matchesSearchQuery_emptyQueryMatchesEverything() {
        #expect(TaggingSheetSelectionPresentation.matchesSearchQuery("Yellowtail", query: ""))
        #expect(TaggingSheetSelectionPresentation.matchesSearchQuery("Yellowtail", query: "   "))
    }

    @Test func matchesSearchQuery_isCaseAndDiacriticInsensitive() {
        #expect(TaggingSheetSelectionPresentation.matchesSearchQuery("Café Blue", query: "cafe"))
        #expect(TaggingSheetSelectionPresentation.matchesSearchQuery("André", query: "andre"))
        #expect(!TaggingSheetSelectionPresentation.matchesSearchQuery("Yellowtail", query: "shark"))
    }
}
