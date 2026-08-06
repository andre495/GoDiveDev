import Foundation

/// Pure helpers for `@DisplayName` mentions of mutual GoDive friends in notes and comments.
enum GoDiveMentionPresentation: Sendable {
    nonisolated static let maxMentionedUIDs = 10
    nonisolated static let autocompleteLimit = 8

    /// Active `@query` at the caret (replacement range includes the leading `@`).
    struct ActiveMention: Equatable, Sendable {
        var query: String
        /// UTF-16 location of `@` in `text`.
        var atUTF16Location: Int
        /// UTF-16 length from `@` through the query (exclusive of caret).
        var utf16Length: Int
    }

    /// Result of inserting a picked friend into compose text.
    struct Insertion: Equatable, Sendable {
        var text: String
        /// New UTF-16 caret after the inserted `@Name `.
        var caretUTF16: Int
    }

    /// Whether `index` can start an `@` mention (start of string or whitespace before).
    nonisolated static func isValidMentionStart(_ text: String, at index: String.Index) -> Bool {
        guard index < text.endIndex, text[index] == "@" else { return false }
        if index == text.startIndex { return true }
        let before = text.index(before: index)
        return text[before].isWhitespace || text[before].isNewline
    }

    /// Active mention query for autocomplete from UTF-16 caret offset.
    /// When `friends` is provided, a completed `@Name ` (picked mention) is not treated as active.
    nonisolated static func activeMention(
        in text: String,
        utf16Caret: Int,
        friends: [GoDiveFriendGraphService.FriendEdge] = []
    ) -> ActiveMention? {
        let ns = text as NSString
        let len = ns.length
        let caret = max(0, min(utf16Caret, len))
        guard caret > 0 else { return nil }

        var atLoc = -1
        var i = caret - 1
        while i >= 0 {
            let ch = ns.character(at: i)
            if ch == 0x40 { // @
                atLoc = i
                break
            }
            // Line break ends the token search upward.
            if ch == 0x0A || ch == 0x0D { return nil }
            i -= 1
        }
        guard atLoc >= 0 else { return nil }

        // Valid start: beginning or whitespace before `@`.
        if atLoc > 0 {
            let before = ns.character(at: atLoc - 1)
            if !isUTF16WhitespaceOrNewline(before) { return nil }
        }

        let queryStart = atLoc + 1
        guard queryStart <= caret else { return nil }
        let query = ns.substring(with: NSRange(location: queryStart, length: caret - queryStart))
        if isCompletedMentionQuery(query, friends: friends) { return nil }
        return ActiveMention(
            query: query,
            atUTF16Location: atLoc,
            utf16Length: caret - atLoc
        )
    }

    /// True when `query` is already a finished `@Name` pick (`Name` + space + optional more).
    nonisolated static func isCompletedMentionQuery(
        _ query: String,
        friends: [GoDiveFriendGraphService.FriendEdge]
    ) -> Bool {
        guard !friends.isEmpty else { return false }
        let lower = query.lowercased()
        for friend in friends.sorted(by: { $0.displayName.count > $1.displayName.count }) {
            let name = friend.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let nameLower = name.lowercased()
            if lower == nameLower + " " { return true }
            if lower.hasPrefix(nameLower + " ") { return true }
        }
        return false
    }

    /// Friends whose display name has the query as a case-insensitive prefix.
    nonisolated static func matchingFriends(
        query: String,
        friends: [GoDiveFriendGraphService.FriendEdge],
        limit: Int = autocompleteLimit
    ) -> [GoDiveFriendGraphService.FriendEdge] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered: [GoDiveFriendGraphService.FriendEdge]
        if q.isEmpty {
            filtered = friends.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        } else {
            filtered = friends
                .filter { $0.displayName.lowercased().hasPrefix(q) }
                .sorted {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
        }
        return Array(filtered.prefix(max(0, limit)))
    }

    /// Replaces the active `@query` with `@DisplayName `.
    nonisolated static func insertMention(
        displayName: String,
        into text: String,
        active: ActiveMention
    ) -> Insertion {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return Insertion(text: text, caretUTF16: active.atUTF16Location + active.utf16Length)
        }
        let ns = text as NSString
        let replacement = "@\(name) "
        let range = NSRange(location: active.atUTF16Location, length: active.utf16Length)
        guard NSMaxRange(range) <= ns.length else {
            return Insertion(text: text, caretUTF16: ns.length)
        }
        let updated = ns.replacingCharacters(in: range, with: replacement)
        let newCaret = active.atUTF16Location + (replacement as NSString).length
        return Insertion(text: updated, caretUTF16: newCaret)
    }

    /// Friends mentioned via `@DisplayName` in `text` (longest name first; unique; capped).
    nonisolated static func mentionedFriends(
        in text: String,
        friends: [GoDiveFriendGraphService.FriendEdge],
        excludingUID: String? = nil,
        maxCount: Int = maxMentionedUIDs
    ) -> [GoDiveFriendGraphService.FriendEdge] {
        let exclude = excludingUID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let candidates = friends
            .filter {
                let uid = $0.friendUID.trimmingCharacters(in: .whitespacesAndNewlines)
                let name = $0.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                return !uid.isEmpty && !name.isEmpty && uid != exclude
            }
            .sorted { $0.displayName.count > $1.displayName.count }

        guard !candidates.isEmpty, !text.isEmpty else { return [] }

        var found: [GoDiveFriendGraphService.FriendEdge] = []
        var seenUIDs = Set<String>()
        var index = text.startIndex
        while index < text.endIndex {
            if text[index] == "@", isValidMentionStart(text, at: index) {
                let afterAt = text.index(after: index)
                let rest = text[afterAt...]
                if let match = candidates.first(where: { friend in
                    mentionMatches(rest: rest, displayName: friend.displayName)
                }) {
                    let uid = match.friendUID.trimmingCharacters(in: .whitespacesAndNewlines)
                    if seenUIDs.insert(uid).inserted {
                        found.append(match)
                        if found.count >= maxCount { return found }
                    }
                    let nameLen = match.displayName.trimmingCharacters(in: .whitespacesAndNewlines).count
                    index = text.index(afterAt, offsetBy: nameLen, limitedBy: text.endIndex) ?? text.endIndex
                    continue
                }
            }
            index = text.index(after: index)
        }
        return found
    }

    nonisolated static func mentionedUIDs(
        in text: String,
        friends: [GoDiveFriendGraphService.FriendEdge],
        excludingUID: String? = nil,
        maxCount: Int = maxMentionedUIDs
    ) -> [String] {
        mentionedFriends(
            in: text,
            friends: friends,
            excludingUID: excludingUID,
            maxCount: maxCount
        ).map(\.friendUID)
    }

    /// Firestore-safe `mentionedUids` array (trim, drop empties/self, cap, unique).
    nonisolated static func sanitizedMentionedUIDs(
        _ raw: [String],
        excludingUID: String?,
        maxCount: Int = maxMentionedUIDs
    ) -> [String] {
        let exclude = excludingUID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var seen = Set<String>()
        var out: [String] = []
        for value in raw {
            let uid = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !uid.isEmpty, uid != exclude else { continue }
            guard seen.insert(uid).inserted else { continue }
            out.append(uid)
            if out.count >= maxCount { break }
        }
        return out
    }

    /// Ranges of `@DisplayName` (including `@`) to color in notes/comments.
    /// Prefers longest known display names; falls back to a single `@token` (no spaces).
    nonisolated static func mentionRanges(
        in text: String,
        knownDisplayNames: [String]
    ) -> [Range<String.Index>] {
        let names = knownDisplayNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }

        guard !text.isEmpty else { return [] }

        var ranges: [Range<String.Index>] = []
        var index = text.startIndex
        while index < text.endIndex {
            if text[index] == "@", isValidMentionStart(text, at: index) {
                let afterAt = text.index(after: index)
                let rest = text[afterAt...]
                if let name = names.first(where: { mentionMatches(rest: rest, displayName: $0) }) {
                    let nameLen = name.count
                    let end = text.index(afterAt, offsetBy: nameLen, limitedBy: text.endIndex)
                        ?? text.endIndex
                    ranges.append(index..<end)
                    index = end
                    continue
                }
                if let tokenEnd = singleTokenMentionEnd(in: text, afterAt: afterAt), tokenEnd > afterAt {
                    ranges.append(index..<tokenEnd)
                    index = tokenEnd
                    continue
                }
            }
            index = text.index(after: index)
        }
        return ranges
    }

    /// Display names useful for coloring mentions on an owned activity (tagged buddies).
    nonisolated static func knownDisplayNames(
        taggedBuddyNames: [String],
        friendNames: [String] = []
    ) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for name in taggedBuddyNames + friendNames {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard seen.insert(key).inserted else { continue }
            out.append(trimmed)
        }
        return out
    }

    // MARK: - Private

    /// End index of a single-token mention body (no spaces), or `afterAt` when empty.
    nonisolated private static func singleTokenMentionEnd(
        in text: String,
        afterAt: String.Index
    ) -> String.Index? {
        guard afterAt < text.endIndex else { return afterAt }
        var end = afterAt
        while end < text.endIndex {
            let ch = text[end]
            if ch.isWhitespace || ch.isNewline || ch == "@" { break }
            if ch.isPunctuation, ch != "'" , ch != "’", ch != "-" { break }
            end = text.index(after: end)
        }
        return end
    }

    nonisolated private static func isUTF16WhitespaceOrNewline(_ unit: unichar) -> Bool {
        if unit == 0x0A || unit == 0x0D || unit == 0x09 || unit == 0x20 { return true }
        // Non-breaking space and other common separators.
        if unit == 0xA0 { return true }
        return false
    }

    nonisolated private static func mentionMatches(
        rest: Substring,
        displayName: String
    ) -> Bool {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        guard rest.count >= name.count else { return false }
        let prefix = rest.prefix(name.count)
        guard prefix.lowercased() == name.lowercased() else { return false }
        if rest.count == name.count { return true }
        let next = rest[rest.index(rest.startIndex, offsetBy: name.count)]
        return next.isWhitespace
            || next.isNewline
            || next.isPunctuation
            || next == "@"
    }
}
