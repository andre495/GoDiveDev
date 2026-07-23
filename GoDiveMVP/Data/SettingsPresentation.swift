import Foundation

/// Copy for **Settings** rows (testable without SwiftUI).
enum SettingsPresentation: Sendable {

    nonisolated static let pageTitle = "Settings"

    enum ImperialUnits {
        nonisolated static let title = "Imperial units"
        nonisolated static let infoMessage =
            "When on, depths show in feet, water temperature in °F, cylinder pressure in psi, tank volume in cubic feet, and diver weight in pounds. Off uses metric (meters, °C, bar, liters, kilograms). Imported values are always stored the same way; this only changes how numbers appear."
    }

    enum DefaultTank {
        nonisolated static let title = "Default tank"
        nonisolated static let infoMessage =
            "Used for new imports and gas details when a dive file does not specify cylinder size or material. Existing dives keep their stored values until re-imported."
    }

    enum DefaultDiverWeights {
        nonisolated static let sectionTitle = "Default Diver Weights"
        nonisolated static let infoMessage =
            "Pre-fills the Weights section on newly imported dives. Clear a field to stop auto-filling that water type. You can still change weight on each dive."
        nonisolated static let saltWaterTitle = "Salt water"
        nonisolated static let freshWaterTitle = "Fresh water"
    }

    enum AutomaticallyRenumberDives {
        nonisolated static let title = "Automatically renumber dives"
        nonisolated static let infoMessage =
            "When on, dive numbers stay 1, 2, 3, … in chronological order whenever you import a dive or delete one. When off, numbers are not adjusted after a delete (imports still get the next number in the existing chain). Dives marked with no number (-) in Details are assigned a number when this runs."
    }

    enum AutoUploadMediaToActivities {
        nonisolated static let title = "Auto-upload media to activities"
        nonisolated static let infoMessage =
            "When on, GoDive reads your Apple Photos library (with your permission) and attaches photos and videos whose capture time falls within each dive’s start and end window. Turning this on scans dives already in your log; new imports are matched automatically. Media stays on your device in GoDive only — nothing is uploaded to a server. With Limited Photos access, only photos you allow are visible to the app."
    }

    enum CrashReports {
        nonisolated static let title = "Crash Reports"
        nonisolated static let infoMessage =
            "GoDive keeps a local record when the app crashes or quits unexpectedly. Open this page after a crash to review or share reports. System crash diagnostics can take until the next launch to appear."
        nonisolated static let emptyStateMessage = "No crashes recorded. If the app crashes, a report appears here on the next launch."
        nonisolated static let exportButtonTitle = "Share"
        nonisolated static let clearButtonTitle = "Clear All"
        nonisolated static let clearConfirmationTitle = "Delete all stored crash reports?"
    }

    enum ICloudDiveLog {
        nonisolated static let title = "iCloud dive log"
        nonisolated static let infoMessage =
            "Your dive log, buddies from imports, and profile photo bytes sync through Apple’s private iCloud database when mirroring is on. Friends, display name, and friend-linked buddies come from GoDive’s social service (Firebase). After reinstalling, GoDive can pull your avatar from Firebase if iCloud has not restored it yet. If private sync is off, dive data from this phone was never mirrored to iCloud and cannot be restored by reinstalling alone."
        nonisolated static func subtitle(for snapshot: GoDiveCloudKitDiveLogLocalStatus.Snapshot) -> String {
            let syncLabel: String = switch snapshot.privateSync {
            case .enabled: "Private sync on"
            case .disabled: "Private sync off"
            case .unknown: "Private sync status unknown"
            }
            let onProfile = snapshot.sessionProfileDiveCount + snapshot.sessionProfileSnorkelCount
            return "\(syncLabel) · \(onProfile) on this profile"
        }
        nonisolated static func detailMessage(for snapshot: GoDiveCloudKitDiveLogLocalStatus.Snapshot) -> String {
            var lines: [String] = []
            lines.append("Dives on this profile: \(snapshot.sessionProfileDiveCount)")
            lines.append("Snorkels on this profile: \(snapshot.sessionProfileSnorkelCount)")
            lines.append("Total on device: \(snapshot.totalDiveCount) dives, \(snapshot.totalSnorkelCount) snorkels")
            if snapshot.appleIDProfileCount > 1 {
                lines.append(
                    "Profiles for this Apple ID on device: \(snapshot.appleIDProfileCount) (merge in progress if activities are split)"
                )
            }
            if snapshot.activitiesOnOtherProfilesForSameAppleID > 0 {
                lines.append(
                    "Activities on other profiles: \(snapshot.activitiesOnOtherProfilesForSameAppleID) — leave the app open on Wi‑Fi; GoDive will merge them automatically."
                )
            }
            if snapshot.sessionProfileDiveCount == 0,
               snapshot.sessionProfileSnorkelCount == 0,
               snapshot.totalDiveCount + snapshot.totalSnorkelCount > 0 {
                lines.append(
                    "Some activities are on this device but not linked to your session yet. Try force-quitting and reopening, or wait a few minutes on Wi‑Fi."
                )
            }
            if let diagnostic = snapshot.lastOpenDiagnosticLine {
                lines.append("Last store open: \(diagnostic)")
            }
            if snapshot.privateSync == .disabled {
                lines.append(
                    "Private sync is off on this device — sign out and sign in again, or restart GoDive, so your iCloud dive log can reconnect automatically."
                )
                if let error = snapshot.lastCloudKitOpenError {
                    lines.append("Last open error: \(error)")
                }
            }
            return lines.joined(separator: "\n")
        }
    }

    enum ShareCrashReports {
        nonisolated static let title = "Share crash reports"
        nonisolated static let infoMessage =
            "When on, crash reports upload automatically to the GoDive developer so problems can be fixed (requires an iCloud account on this device). Reports contain technical diagnostics only — no dive log, photo, or personal data. When off, reports stay on your device; you can still share one manually from Crash Reports."
    }

    enum SecurityEvents {
        nonisolated static let title = "Diagnostic Events"
        nonisolated static let infoMessage =
            "GoDive keeps a short local journal of security-related events (sign-in, sign-out, rejected imports, catalog refresh issues). Events sync with your dive account across your devices. Open this page to review or export them."
        nonisolated static let emptyStateMessage = "No diagnostic events yet. Sign-in, import, and catalog events appear here as they occur."
        nonisolated static let exportButtonTitle = "Share"
        nonisolated static let clearButtonTitle = "Clear All"
        nonisolated static let clearConfirmationTitle = "Delete all stored diagnostic events?"
    }

    enum ShareSecurityEvents {
        nonisolated static let title = "Share diagnostic events"
        nonisolated static let infoMessage =
            "When on, scrubbed diagnostic events upload automatically to the GoDive developer (requires an iCloud account on this device). Events contain short technical tokens only — no dive log, photo, or personal data. When off, the journal stays on your devices; you can still share entries manually from Diagnostic Events."
    }

    enum ShareDives {
        nonisolated static let title = "Share dives with friends"
        nonisolated static let infoMessage =
            "When on, friends can see your dive details (site, depth, duration, conditions, and more). Your private CloudKit log stays the source of truth; a friend-visible copy is stored for them to read. Notes and media stay off unless you enable those toggles."
    }

    enum ShareNotesWithFriends {
        nonisolated static let title = "Share notes with friends"
        nonisolated static let infoMessage =
            "When on, dive notes are included in what friends can see. Off by default."
    }

    enum ShareMediaWithFriends {
        nonisolated static let title = "Share media with friends"
        nonisolated static let infoMessage =
            "When on, small photo previews from your dives upload so friends can see them. Full originals stay in your Photos library. Off by default."
    }

    enum BulkUddfImport {
        nonisolated static let attachMediaTitle = "Attach photos from library"
        nonisolated static let attachMediaSubtitle =
            "Matches Apple Photos and videos to each imported dive by capture time. This step can take a few minutes on a large logbook."
    }

    nonisolated static func infoAccessibilityLabel(forSettingTitle title: String) -> String {
        "More information about \(title)"
    }

    nonisolated static func diverWeightUnitLabel(useImperial: Bool) -> String {
        useImperial ? "lb" : "kg"
    }
}
