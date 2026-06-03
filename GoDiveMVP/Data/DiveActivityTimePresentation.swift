import Foundation

/// Formats dive **`Date`** values using a persisted fixed offset when set, else the device timezone.
enum DiveActivityTimePresentation: Sendable {

    nonisolated static func resolvedTimeZone(forOffsetSeconds offsetSeconds: Int?) -> TimeZone {
        guard let offsetSeconds else { return .current }
        return TimeZone(secondsFromGMT: offsetSeconds) ?? .current
    }

    nonisolated static func format(
        _ value: Date,
        timeZoneOffsetSeconds: Int?,
        dateStyle: Date.FormatStyle.DateStyle = .abbreviated,
        timeStyle: Date.FormatStyle.TimeStyle = .omitted
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = formattingLocale
        formatter.timeZone = resolvedTimeZone(forOffsetSeconds: timeZoneOffsetSeconds)
        let styles = dateFormatterStyles(dateStyle: dateStyle, timeStyle: timeStyle)
        formatter.dateStyle = styles.date
        formatter.timeStyle = styles.time
        return formatter.string(from: value)
    }

    nonisolated static func formatDateTime(_ value: Date, timeZoneOffsetSeconds: Int?) -> String {
        format(value, timeZoneOffsetSeconds: timeZoneOffsetSeconds, dateStyle: .abbreviated, timeStyle: .shortened)
    }

    nonisolated static func formatDateOnly(_ value: Date, timeZoneOffsetSeconds: Int?) -> String {
        format(value, timeZoneOffsetSeconds: timeZoneOffsetSeconds, dateStyle: .abbreviated, timeStyle: .omitted)
    }

    /// Full month name — e.g. **January 5, 2026** (map overview header).
    nonisolated static func formatLongDateOnly(_ value: Date, timeZoneOffsetSeconds: Int?) -> String {
        format(value, timeZoneOffsetSeconds: timeZoneOffsetSeconds, dateStyle: .long, timeStyle: .omitted)
    }

    nonisolated static func formatTimeOnly(_ value: Date, timeZoneOffsetSeconds: Int?) -> String {
        format(value, timeZoneOffsetSeconds: timeZoneOffsetSeconds, dateStyle: .omitted, timeStyle: .shortened)
    }

    /// Stored instant as UTC (**`Z`**) for import/debug rows.
    nonisolated static func formatUTCDateTime(_ value: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return formatter.string(from: value)
    }

    /// Human-readable fixed offset used for dive-local display (e.g. **UTC−04:00**).
    nonisolated static func formatTimeZoneOffsetLabel(offsetSeconds: Int?) -> String {
        guard let offsetSeconds else {
            return "Not set (device timezone)"
        }
        let sign = offsetSeconds >= 0 ? "+" : "-"
        let total = abs(offsetSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return String(format: "UTC%@%d:%02d", sign, hours, minutes)
    }

    /// App locale without **`Locale.current`** (main-actor isolated in Swift 6).
    nonisolated private static var formattingLocale: Locale {
        let identifier = Bundle.main.preferredLocalizations.first ?? "en_US"
        return Locale(identifier: identifier)
    }

    nonisolated private static func dateFormatterStyles(
        dateStyle: Date.FormatStyle.DateStyle,
        timeStyle: Date.FormatStyle.TimeStyle
    ) -> (date: DateFormatter.Style, time: DateFormatter.Style) {
        (dateFormatterStyle(from: dateStyle), timeFormatterStyle(from: timeStyle))
    }

    nonisolated private static func dateFormatterStyle(from style: Date.FormatStyle.DateStyle) -> DateFormatter.Style {
        switch style {
        case .omitted:
            return .none
        case .long:
            return .long
        case .complete:
            return .full
        default:
            return .medium
        }
    }

    nonisolated private static func timeFormatterStyle(from style: Date.FormatStyle.TimeStyle) -> DateFormatter.Style {
        switch style {
        case .omitted:
            return .none
        case .complete:
            return .full
        default:
            return .short
        }
    }
}

extension DiveActivity {
    func formattedStartDateOnly() -> String {
        DiveActivityTimePresentation.formatDateOnly(startTime, timeZoneOffsetSeconds: timeZoneOffsetSeconds)
    }

    func formattedStartDateTime() -> String {
        DiveActivityTimePresentation.formatDateTime(startTime, timeZoneOffsetSeconds: timeZoneOffsetSeconds)
    }

    func formattedStartUTCDateTime() -> String {
        DiveActivityTimePresentation.formatUTCDateTime(startTime)
    }

    func formattedTimeZoneOffsetLabel() -> String {
        DiveActivityTimePresentation.formatTimeZoneOffsetLabel(offsetSeconds: timeZoneOffsetSeconds)
    }
}

extension DiveProfilePoint {
    func formattedTimestamp(for activity: DiveActivity) -> String {
        DiveActivityTimePresentation.formatDateTime(timestamp, timeZoneOffsetSeconds: activity.timeZoneOffsetSeconds)
    }
}
