import Foundation
import SwiftData
#if canImport(Contacts)
import Contacts
#endif

/// Fuzzy-matches unlinked **`DiveBuddy`** roster rows to Apple Contacts after dive import.
enum DiveBuddyContactAutoLink: Sendable {

    struct ContactMatchCandidate: Equatable, Sendable {
        let contactsIdentifier: String
        let displayName: String
    }

    /// Links import dive buddies that have no **`contactsIdentifier`** when exactly one contact fuzzy-matches.
    @MainActor
    static func autoLinkUnlinkedBuddies(
        owner: UserProfile,
        modelContext: ModelContext,
        buddyIDs: Set<UUID>
    ) async {
        #if canImport(Contacts)
        guard DiveBuddyContactsAuthorization.allowsContactMatching,
              !GoDiveUITestConfiguration.isActive,
              !buddyIDs.isEmpty
        else { return }

        let buddies = fetchBuddies(ids: buddyIDs, ownerProfileID: owner.id, modelContext: modelContext)
            .filter { ($0.contactsIdentifier ?? "").isEmpty }
        guard !buddies.isEmpty else { return }

        let contactCandidates = await Task.detached(priority: .utility) {
            (try? fetchContactMatchCandidates()) ?? []
        }.value
        guard !contactCandidates.isEmpty else { return }

        var reservedContactIDs = linkedContactIDs(ownerProfileID: owner.id, modelContext: modelContext)

        for buddy in buddies {
            guard !DiveBuddyCatalog.shouldExcludeBuddyName(buddy.displayName, owner: owner) else { continue }
            guard let contactID = resolvedContactID(
                buddyDisplayName: buddy.displayName,
                candidates: contactCandidates,
                reservedContactIDs: reservedContactIDs
            ) else { continue }

            do {
                try DiveBuddyContactLinking.applyIdentifier(
                    contactID,
                    to: buddy,
                    owner: owner,
                    modelContext: modelContext
                )
                reservedContactIDs.insert(contactID)
            } catch {
                continue
            }
        }
        #endif
    }

    /// Picks a single Contacts row when fuzzy match is unambiguous (testable without **`CNContactStore`**).
    nonisolated static func resolvedContactID(
        buddyDisplayName: String,
        candidates: [ContactMatchCandidate],
        reservedContactIDs: Set<String>
    ) -> String? {
        let scored: [(id: String, score: Int)] = candidates.compactMap { candidate in
            guard !reservedContactIDs.contains(candidate.contactsIdentifier) else { return nil }
            let score = DiveBuddyNameMatching.matchScore(
                importedName: buddyDisplayName,
                rosterName: candidate.displayName
            )
            guard score > 0 else { return nil }
            return (candidate.contactsIdentifier, score)
        }
        guard let topScore = scored.map(\.score).max() else { return nil }
        let topMatches = scored.filter { $0.score == topScore }
        guard topMatches.count == 1 else { return nil }
        return topMatches[0].id
    }

    #if canImport(Contacts)
    /// **`CNContactStore.enumerateContacts`** must not run on the main thread.
    nonisolated static func fetchContactMatchCandidates(
        contactStore: CNContactStore = CNContactStore()
    ) throws -> [ContactMatchCandidate] {
        guard DiveBuddyContactsAuthorization.allowsContactMatching else { return [] }

        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        var results: [ContactMatchCandidate] = []
        try contactStore.enumerateContacts(with: request) { contact, _ in
            if let candidate = contactMatchCandidate(from: contact) {
                results.append(candidate)
            }
        }
        return results
    }

    /// Name extraction for bulk fetch (off main actor); mirrors **`DiveBuddyContactImport.displayName`**.
    nonisolated private static func contactMatchCandidate(from contact: CNContact) -> ContactMatchCandidate? {
        let composed = CNContactFormatter.string(from: contact, style: .fullName)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let displayName: String
        if !composed.isEmpty {
            displayName = String(composed.prefix(DiveBuddyCatalog.maxDisplayNameLength))
        } else {
            let given = contact.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
            let family = contact.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
            let combined = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
            guard !combined.isEmpty else { return nil }
            displayName = String(combined.prefix(DiveBuddyCatalog.maxDisplayNameLength))
        }
        guard displayName != "Buddy" else { return nil }
        let identifier = contact.identifier
        guard !identifier.isEmpty else { return nil }
        return ContactMatchCandidate(contactsIdentifier: identifier, displayName: displayName)
    }

    @MainActor
    private static func fetchBuddies(
        ids: Set<UUID>,
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) -> [DiveBuddy] {
        let all = (try? modelContext.fetch(FetchDescriptor<DiveBuddy>())) ?? []
        return all.filter { ids.contains($0.id) && $0.ownerProfileID == ownerProfileID }
    }

    @MainActor
    private static func linkedContactIDs(
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) -> Set<String> {
        let all = (try? modelContext.fetch(FetchDescriptor<DiveBuddy>())) ?? []
        return Set(
            all.compactMap { buddy -> String? in
                guard buddy.ownerProfileID == ownerProfileID,
                      let id = buddy.contactsIdentifier,
                      !id.isEmpty
                else { return nil }
                return id
            }
        )
    }
    #endif
}
