import Foundation
import FITSwiftSDK

/// FIT **`SessionMesg`** sport / sub-sport gates for dive vs snorkel import pipelines.
enum FitActivitySessionValidation {

    nonisolated static let allowedDiveSubSports: Set<SubSport> = [
        .singleGasDiving,
        .multiGasDiving,
        .gaugeDiving,
        .ccrDiving,
    ]

    nonisolated static let allowedDiveSubSportUserLabels = "Single-Gas, Multi-Gas, CCR, or Gauge"

    /// Exactly one validated scuba dive session, or throws before profile/tank work.
    nonisolated static func diveSessionForImport(from messages: FitMessages) throws -> SessionMesg {
        let divingSessions = messages.sessionMesgs.filter { $0.getSport() == .diving }
        guard !divingSessions.isEmpty else {
            if messages.sessionMesgs.contains(where: FitSnorkelFileDecoder.isAllowedSnorkelSession) {
                throw FitDecodeError.wrongActivityKindForDiveImport
            }
            throw FitDecodeError.noDivingSession
        }
        guard divingSessions.count == 1 else {
            throw FitDecodeError.multipleDivingSessionsInOneFile(sessionCount: divingSessions.count)
        }
        let session = divingSessions[0]
        guard let subSport = session.getSubSport() else {
            throw FitDecodeError.unsupportedDiveSubSport(foundLabel: nil)
        }
        guard allowedDiveSubSports.contains(subSport) else {
            throw FitDecodeError.unsupportedDiveSubSport(foundLabel: subSportUserLabel(subSport))
        }
        return session
    }

    /// Exactly one snorkel / open-water session, or throws before profile work.
    nonisolated static func snorkelSessionForImport(from messages: FitMessages) throws -> SessionMesg {
        let allowed = messages.sessionMesgs.filter { FitSnorkelFileDecoder.isAllowedSnorkelSession($0) }
        guard !allowed.isEmpty else {
            if messages.sessionMesgs.contains(where: { $0.getSport() == .diving }) {
                throw FitSnorkelDecodeError.wrongActivityKindForSnorkelImport
            }
            throw FitSnorkelDecodeError.noSnorkelSession
        }
        guard allowed.count == 1 else {
            throw FitSnorkelDecodeError.multipleSnorkelSessionsInOneFile(sessionCount: allowed.count)
        }
        return allowed[0]
    }

    nonisolated static func subSportUserLabel(_ subSport: SubSport) -> String {
        switch subSport {
        case .singleGasDiving: return "Single-Gas"
        case .multiGasDiving: return "Multi-Gas"
        case .gaugeDiving: return "Gauge"
        case .ccrDiving: return "CCR"
        case .apneaDiving: return "Apnea"
        case .openWater: return "Open Water"
        default:
            return "Other"
        }
    }
}
