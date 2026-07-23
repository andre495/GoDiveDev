import Foundation
import os

/// Console diagnostics for **Buddies** list → buddy / friend detail pushes (filter **BuddiesNavigation** in Console).
enum BuddiesListNavigationDiagnostics {
    private static let log = Logger(subsystem: "PrimoSoftware.GoDiveMVP", category: "BuddiesNavigation")

    private static var buddyDetailInitCount = 0
    private static var buddyDetailBodyEvaluationCount = 0
    private static var heroMapPinChangeCount = 0

    static func logListDestinationAppear(
        destination: String,
        isFriend: Bool,
        sharedDiveCount: Int,
        mapPinCount: Int
    ) {
        log.info(
            "List destination appear dest=\(destination, privacy: .public) friend=\(isFriend, privacy: .public) sharedDives=\(sharedDiveCount, privacy: .public) mapPins=\(mapPinCount, privacy: .public)"
        )
    }

    static func logBuddyDetailInit(
        sharedDiveCount: Int,
        mapPinCount: Int,
        mediaTagCount: Int,
        diveTagCount: Int,
        elapsedMilliseconds: Double
    ) {
        buddyDetailInitCount += 1
        log.info(
            "BuddyDetail init seq=\(buddyDetailInitCount, privacy: .public) sharedDives=\(sharedDiveCount, privacy: .public) mapPins=\(mapPinCount, privacy: .public) mediaTags=\(mediaTagCount, privacy: .public) diveTags=\(diveTagCount, privacy: .public) initMs=\(elapsedMilliseconds, privacy: .public)"
        )
    }

    static func logBuddyDetailBodyEvaluation() {
        buddyDetailBodyEvaluationCount += 1
        if buddyDetailBodyEvaluationCount <= 25 || buddyDetailBodyEvaluationCount % 50 == 0 {
            log.debug("BuddyDetail body eval #\(buddyDetailBodyEvaluationCount, privacy: .public)")
        }
        if buddyDetailBodyEvaluationCount == 100 {
            log.error("BuddyDetail body eval reached 100 — possible SwiftUI layout loop")
        }
    }

    static func resetBuddyDetailSession() {
        buddyDetailBodyEvaluationCount = 0
        heroMapPinChangeCount = 0
        log.debug("BuddyDetail session counters reset")
    }

    static func logBuddyDetailAppear(isSelfBuddy: Bool) {
        log.info("BuddyDetail onAppear selfBuddy=\(isSelfBuddy, privacy: .public)")
    }

    static func logBuddyDetailDisappear() {
        log.debug("BuddyDetail onDisappear")
    }

    static func logBuddyDetailTaskPhase(_ phase: String) {
        log.info("BuddyDetail task \(phase, privacy: .public)")
    }

    static func logBuddyDetailTagChange(
        diveTagCount: Int,
        mediaTagCount: Int,
        source: String
    ) {
        log.info(
            "BuddyDetail tag change source=\(source, privacy: .public) diveTags=\(diveTagCount, privacy: .public) mediaTags=\(mediaTagCount, privacy: .public)"
        )
    }

    static func logBuddyDetailRebuild(
        sharedDiveCount: Int,
        mapPinCount: Int,
        includeSecondary: Bool,
        includeMarineLife: Bool
    ) {
        log.info(
            "BuddyDetail rebuild sharedDives=\(sharedDiveCount, privacy: .public) mapPins=\(mapPinCount, privacy: .public) secondary=\(includeSecondary, privacy: .public) marineLife=\(includeMarineLife, privacy: .public)"
        )
    }

    static func logBuddyHeroModeSync(from: String, to: String, hasMedia: Bool, hasMap: Bool) {
        if from == to {
            log.debug("BuddyDetail hero mode unchanged mode=\(from, privacy: .public)")
        } else {
            log.info(
                "BuddyDetail hero mode \(from, privacy: .public) → \(to, privacy: .public) hasMedia=\(hasMedia, privacy: .public) hasMap=\(hasMap, privacy: .public)"
            )
        }
    }

    static func logHeroMapPinCountChange(
        stylePrefix: String,
        oldCount: Int,
        newCount: Int,
        selectedMode: String,
        isMapContentReady: Bool,
        hasAssociatedMedia: Bool,
        willFallBackToMedia: Bool
    ) {
        heroMapPinChangeCount += 1
        log.info(
            "Hero mapPins \(stylePrefix, privacy: .public) #\(heroMapPinChangeCount, privacy: .public) \(oldCount, privacy: .public)→\(newCount, privacy: .public) mode=\(selectedMode, privacy: .public) mapReady=\(isMapContentReady, privacy: .public) hasMedia=\(hasAssociatedMedia, privacy: .public) fallBack=\(willFallBackToMedia, privacy: .public)"
        )
    }
}
