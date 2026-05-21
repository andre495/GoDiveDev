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
}
