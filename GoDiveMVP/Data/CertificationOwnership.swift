import Foundation
import SwiftData

/// Associates **`Certification`** rows with the signed-in **`UserProfile`**.
enum CertificationOwnership {
    static func assignOwner(_ owner: UserProfile, to certification: Certification) {
        certification.owner = owner
        certification.ownerProfileID = owner.id
    }

    static func items(forOwnerProfileID ownerProfileID: UUID, modelContext: ModelContext) throws -> [Certification] {
        let all = try modelContext.fetch(FetchDescriptor<Certification>())
        return all.filter { $0.ownerProfileID == ownerProfileID }
    }

    static func primaryCertification(
        forOwnerProfileID ownerProfileID: UUID,
        modelContext: ModelContext
    ) throws -> Certification? {
        try items(forOwnerProfileID: ownerProfileID, modelContext: modelContext)
            .first { $0.isPrimaryCert }
    }

    /// Marks **`certification`** as primary and clears **`isPrimaryCert`** on the owner’s other cards.
    @MainActor
    static func setAsPrimary(
        _ certification: Certification,
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) throws {
        let owned = try items(forOwnerProfileID: ownerProfileID, modelContext: modelContext)
        for item in owned {
            item.isPrimaryCert = item.id == certification.id
        }
        try modelContext.save()
    }
}
