import Foundation
import SwiftUI
import UIKit

/// Read-only labels for certification list and detail UI.
enum CertificationPresentation: Sendable {

    struct TypeBadgeStyle: Equatable, Sendable {
        let label: String
        let foreground: Color
        let background: Color
    }

    /// Profile header: newest **`certification`**-type card, else omitted.
    struct ProfileFeaturedCertificationDisplay: Equatable, Sendable {
        let title: String
        /// **`certNumber`** when **`title`** is the certification name.
        let certNumber: String?
    }

    static func typeBadgeStyle(for cardType: CertificationCardType) -> TypeBadgeStyle {
        switch cardType {
        case .certification:
            return TypeBadgeStyle(
                label: cardType.displayName,
                foreground: AppTheme.Colors.accentDeep,
                background: AppTheme.Colors.accentLight.opacity(0.45)
            )
        case .specialty:
            return TypeBadgeStyle(
                label: cardType.displayName,
                foreground: specialtyBadgeForeground,
                background: specialtyBadgeBackground
            )
        }
    }

    /// Newest **`CertificationCardType.certification`** row for profile navigation and subtitle copy.
    static func profileFeaturedCertificationCard(from certifications: [Certification]) -> Certification? {
        certifications
            .filter { $0.cardType == .certification }
            .max(by: { $0.dateAttained < $1.dateAttained })
    }

    /// Newest **`CertificationCardType.certification`** card for the profile subtitle block.
    static func profileFeaturedCertification(from certifications: [Certification]) -> ProfileFeaturedCertificationDisplay? {
        guard let newest = profileFeaturedCertificationCard(from: certifications) else {
            return nil
        }
        let name = newest.certName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            let number = newest.certNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            return ProfileFeaturedCertificationDisplay(
                title: name,
                certNumber: number.isEmpty ? nil : number
            )
        }
        return ProfileFeaturedCertificationDisplay(
            title: title(for: newest),
            certNumber: nil
        )
    }

    /// Profile subtitle: featured certification name when a certification-type card exists.
    static func profileCertificationSubtitle(from certifications: [Certification]) -> String? {
        profileFeaturedCertification(from: certifications)?.title
    }

    /// Certifications list: newest **`dateAttained`** first; **`agency`** tie-break (case-insensitive).
    static func sortedForList(_ certifications: [Certification]) -> [Certification] {
        certifications.sorted { lhs, rhs in
            if lhs.dateAttained != rhs.dateAttained {
                return lhs.dateAttained > rhs.dateAttained
            }
            return lhs.agency.localizedCaseInsensitiveCompare(rhs.agency) == .orderedAscending
        }
    }

    static func title(for certification: Certification) -> String {
        let name = certification.certName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        return agencyNumberLine(for: certification) ?? "Certification"
    }

    /// Single-line subtitle for search / legacy callers (**agency · #number · date** when available).
    static func subtitle(for certification: Certification) -> String {
        let date = listDateLine(for: certification)
        guard let agencyLine = agencyNumberLine(for: certification),
              !certification.certName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return date
        }
        return "\(agencyLine) · \(date)"
    }

    /// List tile middle row: agency and/or **`#certNumber`**.
    static func listAgencyNumberLine(for certification: Certification) -> String {
        agencyNumberLine(for: certification) ?? "—"
    }

    /// List tile bottom row: attained date (or **—**).
    static func listDateLine(for certification: Certification) -> String {
        formattedDate(certification.dateAttained)
    }

    static func agencyNumberLine(for certification: Certification) -> String? {
        let agency = certification.agency.trimmingCharacters(in: .whitespacesAndNewlines)
        let number = formattedCertNumber(certification.certNumber)
        if agency.isEmpty, number == nil { return nil }
        if agency.isEmpty { return number }
        if let number {
            return "\(agency) · \(number)"
        }
        return agency
    }

    /// Cert number for display with a leading **`#`** (empty → **`nil`**).
    static func formattedCertNumber(_ raw: String?) -> String? {
        let number = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !number.isEmpty else { return nil }
        if number.hasPrefix("#") { return number }
        return "#\(number)"
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

    /// Prominent name for certification detail header (prefers **`certName`**).
    static func detailHeaderName(for certification: Certification) -> String {
        let name = certification.certName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        return title(for: certification)
    }

    /// Dives whose start falls on or after the start of the certification attained calendar day.
    nonisolated static func divesLoggedSinceAttainedCount(
        startTimes: some Sequence<Date>,
        dateAttained: Date,
        calendar: Calendar = .current
    ) -> Int {
        let dayStart = calendar.startOfDay(for: dateAttained)
        var count = 0
        for startTime in startTimes where startTime >= dayStart {
            count += 1
        }
        return count
    }

    nonisolated static func divesLoggedSinceAttainedLabel(count: Int) -> String {
        switch count {
        case 0:
            return "0 dives"
        case 1:
            return "1 dive"
        default:
            return "\(count) dives"
        }
    }

    private static var specialtyBadgeForeground: Color {
        Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.82, green: 0.74, blue: 0.98, alpha: 1.0)
                    : UIColor(red: 0.36, green: 0.20, blue: 0.52, alpha: 1.0)
            }
        )
    }

    private static var specialtyBadgeBackground: Color {
        Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.22, green: 0.14, blue: 0.34, alpha: 0.72)
                    : UIColor(red: 0.90, green: 0.84, blue: 0.98, alpha: 1.0)
            }
        )
    }
}
