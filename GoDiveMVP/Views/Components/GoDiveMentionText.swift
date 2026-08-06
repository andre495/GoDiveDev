import SwiftUI

/// Renders plain text with `@DisplayName` mentions shown as the name only (no `@`),
/// tinted and bold (`AppTheme.Colors.mention`).
struct GoDiveMentionText: View {
    let text: String
    var knownDisplayNames: [String] = []
    var font: Font = .body
    var baseForeground: Color = AppTheme.Colors.textPrimary
    var multilineTextAlignment: TextAlignment = .leading

    var body: some View {
        Text(attributed)
            .font(font)
            .multilineTextAlignment(multilineTextAlignment)
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    private var alignment: Alignment {
        switch multilineTextAlignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        @unknown default: return .leading
        }
    }

    private var attributed: AttributedString {
        GoDiveMentionAttributedTextPresentation.attributedString(
            text: text,
            knownDisplayNames: knownDisplayNames,
            baseForeground: baseForeground,
            mentionForeground: AppTheme.Colors.mention
        )
    }
}

enum GoDiveMentionAttributedTextPresentation: Sendable {
    /// Builds display text: mention spans drop the leading `@` and use bold + mention color.
    nonisolated static func attributedString(
        text: String,
        knownDisplayNames: [String],
        baseForeground: Color,
        mentionForeground: Color
    ) -> AttributedString {
        let ranges = GoDiveMentionPresentation.mentionRanges(
            in: text,
            knownDisplayNames: knownDisplayNames
        )
        guard !ranges.isEmpty else {
            var plain = AttributedString(text)
            plain.foregroundColor = baseForeground
            return plain
        }

        var result = AttributedString()
        var cursor = text.startIndex
        for range in ranges {
            if cursor < range.lowerBound {
                var segment = AttributedString(String(text[cursor..<range.lowerBound]))
                segment.foregroundColor = baseForeground
                result.append(segment)
            }
            // Drop leading `@`; keep the display name only.
            let mentionBody = text[range].dropFirst()
            var name = AttributedString(String(mentionBody))
            name.foregroundColor = mentionForeground
            name.inlinePresentationIntent = .stronglyEmphasized
            result.append(name)
            cursor = range.upperBound
        }
        if cursor < text.endIndex {
            var trailing = AttributedString(String(text[cursor...]))
            trailing.foregroundColor = baseForeground
            result.append(trailing)
        }
        return result
    }

    /// Visible mention labels after dropping `@` (for tests / accessibility helpers).
    nonisolated static func displayedMentionNames(
        in text: String,
        knownDisplayNames: [String]
    ) -> [String] {
        GoDiveMentionPresentation.mentionRanges(in: text, knownDisplayNames: knownDisplayNames)
            .map { String(text[$0].dropFirst()) }
    }

    /// Raw `@…` substrings matched in storage form (includes `@`).
    nonisolated static func mentionSubstrings(
        in text: String,
        knownDisplayNames: [String]
    ) -> [String] {
        GoDiveMentionPresentation.mentionRanges(in: text, knownDisplayNames: knownDisplayNames)
            .map { String(text[$0]) }
    }
}
