import Foundation
import Observation
import os
import SwiftData
import SwiftUI

/// Queues per-friend “Share this trip?” confirmations after buddies are added.
@MainActor
@Observable
final class DiveTripShareOfferQueue {
    private static let log = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "TripShareOffer"
    )
    private(set) var current: DiveTripShareOfferPresentation.Candidate?
    private var pending: [DiveTripShareOfferPresentation.Candidate] = []
    private var tripObjectID: PersistentIdentifier?
    private(set) var isSharing = false

    var hasOffer: Bool { current != nil }

    func enqueue(
        candidates: [DiveTripShareOfferPresentation.Candidate],
        for trip: DiveTrip
    ) {
        guard !candidates.isEmpty else { return }
        tripObjectID = trip.persistentModelID
        pending.append(contentsOf: candidates)
        promoteNextIfNeeded()
    }

    func share(modelContext: ModelContext, onFinishedQueue: (() -> Void)? = nil) {
        guard let candidate = current,
              let trip = resolvedTrip(modelContext: modelContext)
        else {
            advance(onFinishedQueue: onFinishedQueue)
            return
        }
        let friendUID = candidate.friendUID
        isSharing = true
        Task { @MainActor in
            defer { isSharing = false }
            do {
                try await GoDiveTripShareSync.shareTrip(
                    trip,
                    withFriendUID: friendUID,
                    modelContext: modelContext
                )
            } catch {
                // Soft-fail — buddy stays on the trip; invite can be retried later.
                Self.log.error(
                    "Trip share invite failed: \(error.localizedDescription, privacy: .public)"
                )
            }
            advance(onFinishedQueue: onFinishedQueue)
        }
    }

    func decline(onFinishedQueue: (() -> Void)? = nil) {
        advance(onFinishedQueue: onFinishedQueue)
    }

    private func promoteNextIfNeeded() {
        guard current == nil else { return }
        current = pending.first
        if !pending.isEmpty {
            pending.removeFirst()
        }
    }

    private func advance(onFinishedQueue: (() -> Void)?) {
        current = nil
        promoteNextIfNeeded()
        if current == nil {
            tripObjectID = nil
            onFinishedQueue?()
        }
    }

    private func resolvedTrip(modelContext: ModelContext) -> DiveTrip? {
        guard let tripObjectID else { return nil }
        return modelContext.model(for: tripObjectID) as? DiveTrip
    }
}

/// Shared alert chrome for trip-share offer confirmations.
enum DiveTripShareOfferAlertModifier {
    @MainActor
    static func alertBinding(
        queue: DiveTripShareOfferQueue
    ) -> Binding<Bool> {
        Binding(
            get: { queue.hasOffer && !queue.isSharing },
            set: { _ in
                // Buttons call share/decline explicitly; ignore system dismiss writes.
            }
        )
    }
}
