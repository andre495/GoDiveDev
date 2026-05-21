import Foundation

/// Read-only labels for certification list and detail UI.
enum CertificationPresentation: Sendable {

    static let profileSubtitleDefault = "GoDive User"

    /// Primary certification copy under the profile display name.
    struct ProfilePrimaryCertificationDisplay: Equatable, Sendable {
        let title: String
        /// **`certNumber`** on the primary card when **`title`** is the certification name.
        let certNumber: String?
    }

    /// Profile header: newest primary **`certName`**, optional **`certNumber`** on the next line, else **`profileSubtitleDefault`**.
    static func profilePrimaryCertification(from certifications: [Certification]) -> ProfilePrimaryCertificationDisplay {
        let primaryCards = certifications.filter(\.isPrimaryCert)
        guard let newestPrimary = primaryCards.max(by: { $0.dateAttained < $1.dateAttained }) else {
            return ProfilePrimaryCertificationDisplay(title: profileSubtitleDefault, certNumber: nil)
        }
        let name = newestPrimary.certName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            let number = newestPrimary.certNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            return ProfilePrimaryCertificationDisplay(
                title: name,
                certNumber: number.isEmpty ? nil : number
            )
        }
        return ProfilePrimaryCertificationDisplay(
            title: title(for: newestPrimary),
            certNumber: nil
        )
    }

    /// Profile subtitle: **`certName`** of the primary card with the newest **`dateAttained`**, else **`profileSubtitleDefault`**.
    static func profileCertificationSubtitle(from certifications: [Certification]) -> String {
        profilePrimaryCertification(from: certifications).title
    }

    static func title(for certification: Certification) -> String {
        let name = certification.certName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        return agencyNumberLine(for: certification) ?? "Certification"
    }

    static func subtitle(for certification: Certification) -> String {
        let date = formattedDate(certification.dateAttained)
        guard let agencyLine = agencyNumberLine(for: certification),
              !certification.certName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return date
        }
        return "\(agencyLine) · \(date)"
    }

    static func agencyNumberLine(for certification: Certification) -> String? {
        let agency = certification.agency.trimmingCharacters(in: .whitespacesAndNewlines)
        let number = certification.certNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if agency.isEmpty, number.isEmpty { return nil }
        if agency.isEmpty { return number }
        if number.isEmpty { return agency }
        return "\(agency) · \(number)"
    }

    static func displayString(_ value: String?) -> String {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return "—"
        }
        return raw
    }

    static func formattedDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    static func yesNo(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }
}
