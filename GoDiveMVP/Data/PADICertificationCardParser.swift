import Foundation

/// Heuristic parser for PADI certification cards (eCard, physical front, or physical back) from Vision OCR line groups.
enum PADICertificationCardParser: Sendable {
    nonisolated static func parse(recognizedLines: [String]) -> PADICertificationCardParseResult? {
        let lines = recognizedLines
            .map(normalizeLine)
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }

        let joined = lines.joined(separator: "\n").uppercased()

        if looksLikePADIBackCard(lines: lines, joinedUppercased: joined) {
            var result = PADICertificationCardParseResult()
            var consumedLineIndexes = Set<Int>()

            markIgnoredBackCardProfileLines(in: lines, consumed: &consumedLineIndexes)
            markIgnoredBackCardBoilerplateLines(in: lines, consumed: &consumedLineIndexes)

            for (index, line) in lines.enumerated() {
                guard !consumedLineIndexes.contains(index) else { continue }

                if result.certNumber == nil, let number = extractLabeledValue(
                    from: line,
                    nextLine: nextLine(after: index, in: lines),
                    labelPattern: diverNumberLabelPattern,
                    inlinePattern: diverNumberInlinePattern
                ) {
                    result.certNumber = number
                    markConsumed(index: index, line: line, labelPattern: diverNumberLabelPattern, in: lines, consumed: &consumedLineIndexes)
                }

                if result.dateAttained == nil, let date = extractCertDate(from: line, nextLine: nextLine(after: index, in: lines)) {
                    result.dateAttained = date
                    markConsumed(index: index, line: line, labelPattern: certDateLabelPattern, in: lines, consumed: &consumedLineIndexes)
                }

                if result.instructorNumber == nil, let number = extractLabeledValue(
                    from: line,
                    nextLine: nextLine(after: index, in: lines),
                    labelPattern: instructorNumberLabelPattern,
                    inlinePattern: instructorNumberInlinePattern
                ) {
                    result.instructorNumber = number
                    markConsumed(index: index, line: line, labelPattern: instructorNumberLabelPattern, in: lines, consumed: &consumedLineIndexes)
                }
            }

            markShopNumberLines(in: lines, consumed: &consumedLineIndexes, result: &result)

            if result.instructor == nil {
                result.instructor = inferInstructorName(from: lines, consumedLineIndexes: consumedLineIndexes)
            }

            applyDiveShopName(from: lines, consumedLineIndexes: &consumedLineIndexes, result: &result)

            finalizePADIAgencyIfNeeded(&result)
            return result.hasAnyField ? result : nil
        }

        if looksLikePADIECard(lines: lines, joinedUppercased: joined) {
            var result = parseECard(lines: lines)
            finalizePADIAgencyIfNeeded(&result)
            return result.hasAnyField ? result : nil
        }

        if looksLikePhysicalFrontCard(lines: lines, joinedUppercased: joined) {
            let result = parsePhysicalFrontCard(lines: lines)
            return result.hasAnyField ? result : nil
        }

        return nil
    }

    // MARK: - Patterns

    private nonisolated static let diverNumberLabelPattern = #"^diver\s*no\.?\s*[:#]?$"#
    private nonisolated static let certDateLabelPattern = #"^cert\.?\s*date\.?\s*[:.]?$"#
    private nonisolated static let instructorNumberLabelPattern = #"^instr\.?\s*no\.?\s*[:#]?$"#
    private nonisolated static let digitValuePattern = #"^[\d][\d\s-]*$"#
    private nonisolated static let cardIdentifierValuePattern = #"^[A-Z0-9][A-Z0-9-]{4,}$"#

    private nonisolated static let certificationLabelPattern = #"^certification\s*[:.]?$"#
    private nonisolated static let birthdateLabelPattern = #"^(?:birth\s*date|birthdate)\s*[:.]?$"#
    private nonisolated static let birthDateInlinePattern = #"^birth\s*date\s*[:.]?\s*\d{1,2}[-\s][A-Za-z]+[-\s]\d{4}$"#
    private nonisolated static let padiNumberLabelPattern = #"^padi\s*no\.?\s*[:#]?$"#
    private nonisolated static let combinedDateAndPadiHeaderPattern = #"^cert\.?\s*date\.?\s+padi\s*no\.?\s*[:.]?$"#
    private nonisolated static let padiNumberValuePattern = #"^[A-Z0-9]{6,14}$"#

    private nonisolated static let diverNumberInlinePattern = #"diver\s*no\.?\s*[:#]?\s*([A-Z0-9][A-Z0-9-]+)"#
    private nonisolated static let certDateInlinePattern = #"cert\.?\s*date\s*[:.]?\s*(\d{1,2}[-\s][A-Za-z]+[-\s]\d{4})"#
    private nonisolated static let instructorNumberInlinePattern = #"instr\.?\s*no\.?\s*[:#]?\s*([A-Z0-9][A-Z0-9-]+)"#
    private nonisolated static let padiNumberInlinePattern = #"padi\s*no\.?\s*[:#]?\s*([A-Z0-9]{6,14})"#
    private nonisolated static let bareCertDatePattern = #"^\d{1,2}[-\s][A-Za-z]+[-\s]\d{4}$"#
    private nonisolated static let leadingCertDateTokenPattern = #"^(\d{1,2}[-\s][A-Za-z]+[-\s]\d{4})"#
    private nonisolated static let locationPattern = #"\b(USA|U\.S\.A\.|UNITED STATES|UK|CANADA|AUSTRALIA)\b"#

    // MARK: - Detection

    private nonisolated static func looksLikePADIECard(lines: [String], joinedUppercased: String) -> Bool {
        if lines.contains(where: { wholeMatchOnly($0, pattern: certificationLabelPattern) }) { return true }
        if lines.contains(where: { wholeMatchOnly($0, pattern: birthdateLabelPattern) }) { return true }
        if lines.contains(where: { wholeMatchOnly($0, pattern: padiNumberLabelPattern) }) { return true }
        if lines.contains(where: { wholeMatchOnly($0, pattern: combinedDateAndPadiHeaderPattern) }) { return true }
        if lines.contains(where: { firstCapture(in: $0, pattern: padiNumberInlinePattern) != nil }) { return true }
        return false
    }

    private nonisolated static func looksLikePADIBackCard(lines: [String], joinedUppercased: String) -> Bool {
        if lines.contains(where: { wholeMatchOnly($0, pattern: combinedDateAndPadiHeaderPattern) }) {
            return false
        }
        if lines.contains(where: { wholeMatchOnly($0, pattern: certificationLabelPattern) }) {
            return false
        }
        if lines.contains(where: { firstCapture(in: $0, pattern: diverNumberInlinePattern) != nil }) { return true }
        if lines.contains(where: { firstCapture(in: $0, pattern: certDateInlinePattern) != nil }) { return true }
        if lines.contains(where: { firstCapture(in: $0, pattern: instructorNumberInlinePattern) != nil }) { return true }
        if lines.contains(where: { wholeMatchOnly($0, pattern: diverNumberLabelPattern) }) { return true }
        if lines.contains(where: { wholeMatchOnly($0, pattern: certDateLabelPattern) }) { return true }
        if lines.contains(where: { wholeMatchOnly($0, pattern: instructorNumberLabelPattern) }) { return true }
        if lines.contains(where: { wholeMatchOnly($0, pattern: birthdateLabelPattern) }) { return true }
        if lines.contains(where: { wholeMatchOnly($0, pattern: birthDateInlinePattern) }) { return true }
        if joinedUppercased.contains("DIVER NO") { return true }
        if joinedUppercased.contains("CERT DATE") || joinedUppercased.contains("CERT. DATE") { return true }
        if joinedUppercased.contains("INSTR") && joinedUppercased.contains("NO") { return true }
        return false
    }

    private nonisolated static func looksLikePhysicalFrontCard(lines: [String], joinedUppercased: String) -> Bool {
        guard !looksLikePADIBackCard(lines: lines, joinedUppercased: joinedUppercased) else { return false }
        guard !looksLikePADIECard(lines: lines, joinedUppercased: joinedUppercased) else { return false }
        return bestCertificationTitle(from: certificationTitleCandidates(from: lines)) != nil
    }

    // MARK: - eCard layout

    private nonisolated static func parseECard(lines: [String]) -> PADICertificationCardParseResult {
        var result = PADICertificationCardParseResult()
        var consumed = Set<Int>()

        markIgnoredECardProfileLines(in: lines, consumed: &consumed)

        for (index, line) in lines.enumerated() {
            guard !consumed.contains(index) else { continue }

            if result.certName == nil, wholeMatchOnly(line, pattern: certificationLabelPattern) {
                if let next = nextLine(after: index, in: lines), !isECardLabelLine(next) {
                    result.certName = resolveCertificationTitle(from: next) ?? titleCaseCertificationName(next)
                    consumed.insert(index)
                    consumed.insert(index + 1)
                }
            }
        }

        for (index, line) in lines.enumerated() {
            guard !consumed.contains(index) else { continue }

            if wholeMatchOnly(line, pattern: combinedDateAndPadiHeaderPattern),
               let valueLine = nextLine(after: index, in: lines) {
                if result.dateAttained == nil {
                    result.dateAttained = extractDateToken(from: valueLine)
                }
                if result.certNumber == nil {
                    result.certNumber = extractPadiNumberToken(from: valueLine)
                }
                consumed.insert(index)
                consumed.insert(index + 1)
                continue
            }

            if result.certNumber == nil, let number = extractLabeledPadiNumber(
                from: line,
                nextLine: nextLine(after: index, in: lines)
            ) {
                result.certNumber = number
                markConsumed(index: index, line: line, labelPattern: padiNumberLabelPattern, in: lines, consumed: &consumed)
            }

            if result.dateAttained == nil, let date = extractECardCertDate(
                from: line,
                nextLine: nextLine(after: index, in: lines)
            ) {
                result.dateAttained = date
                markConsumed(index: index, line: line, labelPattern: certDateLabelPattern, in: lines, consumed: &consumed)
            }

            if result.dateAttained == nil, let date = extractDateToken(from: line) {
                result.dateAttained = date
                consumed.insert(index)
            }

            if result.certNumber == nil, let number = extractPadiNumberToken(from: line) {
                result.certNumber = number
                consumed.insert(index)
            }
        }

        return result
    }

    // MARK: - Physical front layout

    private nonisolated static let knownAgencies = ["PADI", "SSI", "NAUI", "SDI", "TDI", "RAID", "BSAC", "CMAS"]

    private nonisolated static let knownCertificationTitles = [
        "Advanced Open Water Diver",
        "Adventure Diver",
        "Assistant Instructor",
        "Deep Diver",
        "Divemaster",
        "Dry Suit Diver",
        "Emergency First Response",
        "Enriched Air Diver",
        "Master Scuba Diver",
        "Master Scuba Diver Trainer",
        "Night Diver",
        "Open Water Diver",
        "Open Water Scuba Instructor",
        "Rescue Diver",
        "Wreck Diver",
    ]

    private nonisolated static func parsePhysicalFrontCard(lines: [String]) -> PADICertificationCardParseResult {
        var result = PADICertificationCardParseResult()
        var consumed = Set<Int>()

        for (index, line) in lines.enumerated() {
            if looksLikeCardHolderName(line) {
                consumed.insert(index)
            }
            if looksLikeAgencyTagline(line) {
                consumed.insert(index)
            }
        }

        for (index, line) in lines.enumerated() {
            guard !consumed.contains(index) else { continue }
            if let agency = matchKnownAgency(line) {
                result.agency = agency
                result.agencyDetectedFromCard = true
                consumed.insert(index)
            }
        }

        if !result.agencyDetectedFromCard,
           lines.contains(where: { normalizedAgencyToken($0).contains("PADI") }) {
            result.agency = "PADI"
            result.agencyDetectedFromCard = true
        }

        if let certName = bestCertificationTitle(from: certificationTitleCandidates(from: lines)) {
            result.certName = certName
            if !result.agencyDetectedFromCard {
                result.agency = "PADI"
                result.agencyDetectedFromCard = true
            }
        }

        return result
    }

    private nonisolated static func finalizePADIAgencyIfNeeded(_ result: inout PADICertificationCardParseResult) {
        guard result.hasAnyField, !result.agencyDetectedFromCard else { return }
        result.agency = "PADI"
        result.agencyDetectedFromCard = true
    }

    private nonisolated static func bestCertificationTitle(from candidates: [String]) -> String? {
        var best: String?
        for candidate in candidates {
            guard let title = resolveCertificationTitle(from: candidate) else { continue }
            if best == nil || title.count > best!.count {
                best = title
            }
        }
        return best
    }

    private nonisolated static func certificationTitleCandidates(from lines: [String]) -> [String] {
        var candidates: [String] = []
        var seen = Set<String>()

        func append(_ value: String) {
            let normalized = normalizeLine(value)
            guard !normalized.isEmpty else { return }
            let key = normalized.uppercased()
            guard !seen.contains(key) else { return }
            seen.insert(key)
            candidates.append(normalized)
        }

        for index in lines.indices {
            guard index + 1 < lines.count else { continue }
            let left = lines[index]
            let right = lines[index + 1]
            guard !isIgnoredCardBoilerplate(left),
                  !isIgnoredCardBoilerplate(right),
                  matchKnownAgency(left) == nil,
                  matchKnownAgency(right) == nil else {
                continue
            }
            append("\(left) \(right)")
        }

        for index in lines.indices {
            guard index + 2 < lines.count else { continue }
            let left = lines[index]
            let middle = lines[index + 1]
            let right = lines[index + 2]
            guard !isIgnoredCardBoilerplate(left),
                  !isIgnoredCardBoilerplate(middle),
                  !isIgnoredCardBoilerplate(right),
                  matchKnownAgency(left) == nil,
                  matchKnownAgency(middle) == nil,
                  matchKnownAgency(right) == nil else {
                continue
            }
            append("\(left) \(middle) \(right)")
        }

        for line in lines where !isIgnoredCardBoilerplate(line) && matchKnownAgency(line) == nil {
            append(line)
        }

        return candidates
    }

    private nonisolated static func matchKnownAgency(_ line: String) -> String? {
        let trimmed = normalizedAgencyToken(line)
        for agency in knownAgencies where trimmed == agency || trimmed.hasPrefix(agency) {
            return agency
        }
        return nil
    }

    private nonisolated static func normalizedAgencyToken(_ line: String) -> String {
        normalizeLine(line)
            .uppercased()
            .replacingOccurrences(of: "®", with: "")
            .replacingOccurrences(of: "™", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }

    private nonisolated static func resolveCertificationTitle(from line: String) -> String? {
        let normalized = normalizeLine(line).uppercased()
        guard !normalized.isEmpty else { return nil }
        if normalized.contains("DIVER NO") || normalized.contains("CERT DATE") || normalized.contains("INSTR") {
            return nil
        }

        var bestMatch: String?
        for title in knownCertificationTitles {
            let token = title.uppercased()
            if normalized == token || normalized.contains(token) {
                if bestMatch == nil || title.count > bestMatch!.count {
                    bestMatch = title
                }
            }
        }

        if let bestMatch {
            return bestMatch
        }

        guard looksLikeCertificationTitle(line) else { return nil }
        return titleCaseCertificationName(line)
    }

    private nonisolated static func looksLikeCertificationTitle(_ line: String) -> Bool {
        let normalized = normalizeLine(line).uppercased()
        if normalized.contains("DIVER NO") || normalized.contains("CERT DATE") || normalized.contains("INSTR") {
            return false
        }
        return certificationTitleKeywords.contains { normalized.contains($0) }
    }

    private nonisolated static let certificationTitleKeywords = [
        "OPEN WATER",
        "RESCUE DIVER",
        "DIVEMASTER",
        "INSTRUCTOR",
        "SCUBA DIVER",
        "MASTER SCUBA",
        "ENRICHED AIR",
        "NITROX",
        "ADVANCED OPEN",
        "WRECK DIVER",
        "DEEP DIVER",
        "NIGHT DIVER",
    ]

    private nonisolated static func looksLikeAgencyTagline(_ line: String) -> Bool {
        isIgnoredCardBoilerplate(line)
    }

    private nonisolated static let cardBoilerplateSubstrings = [
        "THIS DIVER",
        "THIS QUALIFICATION",
        "QUALIFICATION MEETS",
        "MEETS THE QUALIFICATION",
        "MEETS THE STANDARDS",
        "SATISFACTORILY MET",
        "CERTIFICATION LEVEL",
        "SET FORTH BY",
        "MEETS ISO",
        "STANDARDS FOR THIS",
        "AUTONOMOUS DIVER STANDARD",
        "DIVER LEVEL",
        "PROFESSIONAL ASSOCIATION",
        "WWW.",
        "HTTP://",
        "HTTP",
    ]

    private nonisolated static let maxLikelyShopNameLength = 42

    /// PADI card footers, ISO blurbs, and other prose that should never map to form fields.
    private nonisolated static func isIgnoredCardBoilerplate(_ line: String) -> Bool {
        let upper = normalizeLine(line).uppercased()
        guard !upper.isEmpty else { return true }

        if upper.hasPrefix("THIS ") || upper.hasPrefix("FOR THIS ") {
            return true
        }

        if cardBoilerplateSubstrings.contains(where: { upper.contains($0) }) {
            return true
        }

        if upper.contains("ASSOCIATION") || upper.contains("STANDARD") || upper.contains("ISO ") {
            return true
        }

        if upper.count > maxLikelyShopNameLength {
            return true
        }

        if upper.contains("."), upper.count > 24 {
            return true
        }

        return false
    }

    private nonisolated static func titleCaseCertificationName(_ line: String) -> String {
        normalizeLine(line)
            .split(separator: " ")
            .map { word in
                let lower = word.lowercased()
                if lower == "ow" || lower == "aow" {
                    return word.uppercased()
                }
                return word.prefix(1).uppercased() + word.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }

    private nonisolated static func markIgnoredECardProfileLines(in lines: [String], consumed: inout Set<Int>) {
        for (index, line) in lines.enumerated() {
            if wholeMatchOnly(line, pattern: birthdateLabelPattern) {
                consumed.insert(index)
                if index + 1 < lines.count {
                    consumed.insert(index + 1)
                }
            }

            if line.lowercased() == "edit photo" {
                consumed.insert(index)
            }
        }

        if let certificationIndex = lines.firstIndex(where: { wholeMatchOnly($0, pattern: certificationLabelPattern) }) {
            for index in 0 ..< certificationIndex {
                consumed.insert(index)
            }
        }
    }

    private nonisolated static func isECardLabelLine(_ line: String) -> Bool {
        wholeMatchOnly(line, pattern: certificationLabelPattern)
            || wholeMatchOnly(line, pattern: birthdateLabelPattern)
            || wholeMatchOnly(line, pattern: padiNumberLabelPattern)
            || wholeMatchOnly(line, pattern: combinedDateAndPadiHeaderPattern)
            || wholeMatchOnly(line, pattern: certDateLabelPattern)
    }

    private nonisolated static func extractLabeledPadiNumber(from line: String, nextLine: String?) -> String? {
        if let inline = firstCapture(in: line, pattern: padiNumberInlinePattern) {
            return normalizePadiNumber(inline)
        }

        if wholeMatchOnly(line, pattern: padiNumberLabelPattern), let nextLine {
            let trimmed = normalizeLine(nextLine)
            if wholeMatchOnly(trimmed, pattern: padiNumberValuePattern) {
                return normalizePadiNumber(trimmed)
            }
        }

        return nil
    }

    private nonisolated static func extractECardCertDate(from line: String, nextLine: String?) -> Date? {
        if let inline = firstCapture(in: line, pattern: certDateInlinePattern) {
            return parseCertDate(inline)
        }

        if wholeMatchOnly(line, pattern: certDateLabelPattern), let nextLine {
            return extractDateToken(from: nextLine)
        }

        return nil
    }

    private nonisolated static func extractDateToken(from line: String) -> Date? {
        if let token = firstCapture(in: line, pattern: leadingCertDateTokenPattern) {
            return parseCertDate(token)
        }

        if wholeMatchOnly(line, pattern: bareCertDatePattern) {
            return parseCertDate(line)
        }

        return nil
    }

    private nonisolated static func extractPadiNumberToken(from line: String) -> String? {
        let tokens = normalizeLine(line).split(separator: " ").map(String.init)
        for token in tokens.reversed() {
            if wholeMatchOnly(token, pattern: padiNumberValuePattern) {
                return normalizePadiNumber(token)
            }
        }
        return nil
    }

    // MARK: - Back-card profile noise

    private nonisolated static func markIgnoredBackCardProfileLines(in lines: [String], consumed: inout Set<Int>) {
        for (index, line) in lines.enumerated() {
            if wholeMatchOnly(line, pattern: birthdateLabelPattern) {
                consumed.insert(index)
                if index + 1 < lines.count {
                    consumed.insert(index + 1)
                }
            }

            if wholeMatchOnly(line, pattern: birthDateInlinePattern) {
                consumed.insert(index)
            }
        }

        if let dataStart = firstBackCardDataLineIndex(in: lines) {
            for index in 0 ..< dataStart where looksLikeCardHolderName(lines[index]) {
                consumed.insert(index)
            }
        }
    }

    private nonisolated static func markIgnoredBackCardBoilerplateLines(in lines: [String], consumed: inout Set<Int>) {
        for (index, line) in lines.enumerated() where isIgnoredCardBoilerplate(line) {
            consumed.insert(index)
        }
    }

    private nonisolated static func firstBackCardDataLineIndex(in lines: [String]) -> Int? {
        lines.firstIndex { line in
            wholeMatchOnly(line, pattern: diverNumberLabelPattern)
                || firstCapture(in: line, pattern: diverNumberInlinePattern) != nil
                || wholeMatchOnly(line, pattern: birthdateLabelPattern)
                || wholeMatchOnly(line, pattern: birthDateInlinePattern)
        }
    }

    private nonisolated static func looksLikeCardHolderName(_ line: String) -> Bool {
        let trimmed = normalizeLine(line)
        let words = trimmed.split(separator: " ").filter { !$0.isEmpty }
        guard (2 ... 4).contains(words.count) else { return false }
        return words.allSatisfy { word in
            word.allSatisfy { $0.isLetter || $0 == "-" || $0 == "'" || $0 == "." }
        }
    }

    // MARK: - Back-card labeled extraction

    private nonisolated static func extractLabeledValue(
        from line: String,
        nextLine: String?,
        labelPattern: String,
        inlinePattern: String
    ) -> String? {
        if let inline = firstCapture(in: line, pattern: inlinePattern) {
            return normalizeCardIdentifier(inline)
        }

        if wholeMatchOnly(line, pattern: labelPattern), let nextLine {
            let trimmed = normalizeLine(nextLine)
            if wholeMatchOnly(trimmed, pattern: cardIdentifierValuePattern) {
                return normalizeCardIdentifier(trimmed)
            }
            if wholeMatchOnly(trimmed, pattern: digitValuePattern) {
                return normalizeDigits(trimmed)
            }
        }

        return nil
    }

    private nonisolated static func extractCertDate(from line: String, nextLine: String?) -> Date? {
        if let inline = firstCapture(in: line, pattern: certDateInlinePattern) {
            return parseCertDate(inline)
        }

        if wholeMatchOnly(line, pattern: certDateLabelPattern), let nextLine {
            return parseCertDate(normalizeLine(nextLine))
        }

        if wholeMatchOnly(line, pattern: bareCertDatePattern) {
            return parseCertDate(line)
        }

        return nil
    }

    private nonisolated static func markConsumed(
        index: Int,
        line: String,
        labelPattern: String,
        in lines: [String],
        consumed: inout Set<Int>
    ) {
        consumed.insert(index)
        if wholeMatchOnly(line, pattern: labelPattern), index + 1 < lines.count {
            consumed.insert(index + 1)
        }
    }

    // MARK: - Unlabeled inference

    private nonisolated static func inferInstructorName(
        from lines: [String],
        consumedLineIndexes: Set<Int>
    ) -> String? {
        if let instrIndex = lines.firstIndex(where: {
            firstCapture(in: $0, pattern: instructorNumberInlinePattern) != nil
                || wholeMatchOnly($0, pattern: instructorNumberLabelPattern)
        }) {
            let searchStart = min(instrIndex + 1, lines.count)
            for index in searchStart ..< lines.count {
                guard !consumedLineIndexes.contains(index) else { continue }
                let line = lines[index]
                if let name = normalizedPersonName(from: line), !looksLikeLocation(line), !isIgnoredCardBoilerplate(line) {
                    return name
                }
            }
            return nil
        }

        return firstNameLikeLine(from: lines, consumedLineIndexes: consumedLineIndexes)
    }

    private nonisolated static func markShopNumberLines(
        in lines: [String],
        consumed: inout Set<Int>,
        result: inout PADICertificationCardParseResult
    ) {
        let reservedNumbers = Set(
            [result.certNumber, result.instructorNumber].compactMap { $0 }
        )

        for (index, line) in lines.enumerated() {
            guard !consumed.contains(index) else { continue }
            if let number = extractShopNumber(from: line, reservedNumbers: reservedNumbers) {
                if result.diveShopNumber == nil {
                    result.diveShopNumber = number
                }
                consumed.insert(index)
                continue
            }

            if result.diveShopNumber == nil,
               let trailingNumber = extractTrailingShopNumber(from: line, reservedNumbers: reservedNumbers) {
                result.diveShopNumber = trailingNumber
            }
        }
    }

    private nonisolated static func applyDiveShopName(
        from lines: [String],
        consumedLineIndexes: inout Set<Int>,
        result: inout PADICertificationCardParseResult
    ) {
        var shopName: String?
        var shopNumberIndex: Int?

        if let instructor = result.instructor,
           let instructorIndex = lines.firstIndex(where: { normalizedPersonName(from: $0) == instructor }) {
            let nextIndex = instructorIndex + 1
            if nextIndex < lines.count,
               !consumedLineIndexes.contains(nextIndex),
               looksLikeShopName(lines[nextIndex]) {
                shopName = lines[nextIndex]
                consumedLineIndexes.insert(nextIndex)
            }
        }

        if shopName == nil,
           let instrLabelIndex = lines.firstIndex(where: { wholeMatchOnly($0, pattern: instructorNumberLabelPattern) }) {
            for index in (instrLabelIndex + 2) ..< lines.count {
                guard !consumedLineIndexes.contains(index) else { continue }
                if looksLikeLocation(lines[index]) { continue }
                if looksLikeShopName(lines[index]) {
                    shopName = lines[index]
                    consumedLineIndexes.insert(index)
                    break
                }
            }
        }

        if let existingNumber = result.diveShopNumber {
            shopNumberIndex = lines.firstIndex { line in
                normalizeDigits(line) == existingNumber
            }
        }

        for (index, line) in lines.enumerated() {
            guard !consumedLineIndexes.contains(index) else { continue }
            if looksLikeLocation(line) { continue }
            if isIgnoredCardBoilerplate(line) { continue }
            if let instructor = result.instructor,
               normalizedPersonName(from: line) == instructor {
                continue
            }
            if firstCapture(in: line, pattern: diverNumberInlinePattern) != nil
                || firstCapture(in: line, pattern: certDateInlinePattern) != nil
                || firstCapture(in: line, pattern: instructorNumberInlinePattern) != nil {
                continue
            }
            if normalizedAgencyToken(line) == "PADI" { continue }
            if parseCertDate(line) != nil { continue }
            if wholeMatchOnly(line, pattern: birthDateInlinePattern) { continue }
            if extractShopNumber(from: line, reservedNumbers: []) != nil { continue }

            if shopName == nil, looksLikeShopName(line) {
                shopName = line
            }
        }

        if shopName == nil,
           let shopNumberIndex,
           shopNumberIndex + 1 < lines.count {
            let nextIndex = shopNumberIndex + 1
            guard !consumedLineIndexes.contains(nextIndex) else {
                result.diveShop = shopName.map(titleCaseOrganizationName)
                return
            }
            let candidate = lines[nextIndex]
            if !looksLikeLocation(candidate),
               !isIgnoredCardBoilerplate(candidate),
               parseCertDate(candidate) == nil,
               extractShopNumber(from: candidate, reservedNumbers: []) == nil,
               normalizedAgencyToken(candidate) != "PADI" {
                shopName = candidate
            }
        }

        result.diveShop = shopName.map(titleCaseOrganizationName)
    }

    private nonisolated static func firstNameLikeLine(
        from lines: [String],
        consumedLineIndexes: Set<Int>
    ) -> String? {
        for (index, line) in lines.enumerated() {
            guard !consumedLineIndexes.contains(index) else { continue }
            if let name = normalizedPersonName(from: line), !looksLikeLocation(line), !isIgnoredCardBoilerplate(line) {
                return name
            }
        }
        return nil
    }

    private nonisolated static func extractShopNumber(from line: String, reservedNumbers: Set<String>) -> String? {
        guard wholeMatchOnly(line, pattern: digitValuePattern) else { return nil }
        let normalized = normalizeDigits(line)
        guard (4 ... 7).contains(normalized.count), !reservedNumbers.contains(normalized) else { return nil }
        return normalized
    }

    private nonisolated static func extractTrailingShopNumber(from line: String, reservedNumbers: Set<String>) -> String? {
        let tokens = normalizeLine(line).split(separator: " ").map(String.init)
        guard tokens.count >= 2, let last = tokens.last else { return nil }
        guard wholeMatchOnly(last, pattern: digitValuePattern) else { return nil }
        let normalized = normalizeDigits(last)
        guard (4 ... 7).contains(normalized.count), !reservedNumbers.contains(normalized) else { return nil }
        return normalized
    }

    private nonisolated static func normalizedPersonName(from line: String) -> String? {
        let tokens = normalizeLine(line)
            .split(separator: " ")
            .map(String.init)
            .filter { token in
                let digits = normalizeDigits(token)
                guard !digits.isEmpty else { return true }
                return digits.count != token.count
            }

        guard (2 ... 4).contains(tokens.count) else { return nil }
        guard tokens.allSatisfy({ token in
            token.allSatisfy { $0.isLetter || $0 == "-" || $0 == "'" || $0 == "." }
        }) else {
            return nil
        }

        return titleCaseName(tokens.joined(separator: " "))
    }

    private nonisolated static func titleCaseOrganizationName(_ line: String) -> String {
        titleCaseName(line)
    }

    // MARK: - Regex helpers

    private nonisolated static func firstCapture(
        in string: String,
        pattern: String,
        options: NSRegularExpression.Options = [.caseInsensitive]
    ) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let range = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: string) else {
            return nil
        }
        return String(string[captureRange])
    }

    private nonisolated static func wholeMatchOnly(_ string: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return false }
        let range = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, options: [], range: range) else { return false }
        return match.range.location != NSNotFound && match.range.length == (string as NSString).length
    }

    // MARK: - Helpers

    private nonisolated static func normalizeLine(_ line: String) -> String {
        normalizeOCRHomoglyphs(line)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Vision sometimes returns Cyrillic letters that look like Latin (e.g. **А**pr vs **A**pr).
    private nonisolated static func normalizeOCRHomoglyphs(_ line: String) -> String {
        String(line.map { character in
            switch character {
            case "\u{0410}": "A"
            case "\u{0415}": "E"
            case "\u{041E}": "O"
            case "\u{0420}": "P"
            case "\u{0421}": "C"
            case "\u{0425}": "X"
            case "\u{0430}": "a"
            case "\u{0435}": "e"
            case "\u{043E}": "o"
            case "\u{0440}": "p"
            case "\u{0441}": "c"
            case "\u{0445}": "x"
            default: character
            }
        })
    }

    private nonisolated static func normalizeDigits(_ value: String) -> String {
        value.filter(\.isNumber)
    }

    private nonisolated static func normalizeCardIdentifier(_ value: String) -> String {
        value.uppercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }

    private nonisolated static func normalizePadiNumber(_ value: String) -> String {
        value.uppercased().filter { $0.isLetter || $0.isNumber }
    }

    private nonisolated static func nextLine(after index: Int, in lines: [String]) -> String? {
        guard index + 1 < lines.count else { return nil }
        return lines[index + 1]
    }

    private nonisolated static func parseCertDate(_ raw: String) -> Date? {
        let trimmed = normalizeLine(raw)
        guard let regex = try? NSRegularExpression(
            pattern: #"^(\d{1,2})[-\s]([A-Za-z]+)[-\s](\d{4})$"#,
            options: [.caseInsensitive]
        ) else { return nil }

        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, options: [], range: range),
              match.numberOfRanges == 4,
              let dayRange = Range(match.range(at: 1), in: trimmed),
              let monthRange = Range(match.range(at: 2), in: trimmed),
              let yearRange = Range(match.range(at: 3), in: trimmed) else {
            return nil
        }

        let day = Int(trimmed[dayRange]) ?? 0
        let monthToken = String(trimmed[monthRange]).lowercased()
        let year = Int(trimmed[yearRange]) ?? 0

        guard let month = monthNumber(for: monthToken), (1 ... 31).contains(day), (1950 ... 2100).contains(year) else {
            return nil
        }

        return wallClockDate(year: year, month: month, day: day)
    }

    /// Date-only values from card OCR — local calendar day so **`DatePicker`** shows the printed date.
    nonisolated static func wallClockDate(year: Int, month: Int, day: Int) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    nonisolated static func wallClockDateComponents(from date: Date) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.dateComponents([.year, .month, .day], from: date)
    }

    private nonisolated static func monthNumber(for token: String) -> Int? {
        let lower = token.lowercased()
        if let fullMonth = fullMonthNumbers[lower] {
            return fullMonth
        }

        switch lower.prefix(3) {
        case "jan": return 1
        case "feb": return 2
        case "mar": return 3
        case "apr": return 4
        case "may": return 5
        case "jun": return 6
        case "jul": return 7
        case "aug": return 8
        case "sep": return 9
        case "oct": return 10
        case "nov": return 11
        case "dec": return 12
        default: return nil
        }
    }

    private nonisolated static let fullMonthNumbers: [String: Int] = [
        "january": 1,
        "february": 2,
        "march": 3,
        "april": 4,
        "may": 5,
        "june": 6,
        "july": 7,
        "august": 8,
        "september": 9,
        "october": 10,
        "november": 11,
        "december": 12,
    ]

    private nonisolated static func looksLikePersonName(_ line: String) -> Bool {
        let trimmed = normalizeLine(line)
        let words = trimmed.split(separator: " ").filter { !$0.isEmpty }
        guard (2 ... 4).contains(words.count) else { return false }
        return words.allSatisfy { word in
            word.allSatisfy { $0.isLetter || $0 == "-" || $0 == "'" }
        }
    }

    private nonisolated static func looksLikeShopName(_ line: String) -> Bool {
        let trimmed = normalizeLine(line)
        guard trimmed.count >= 4 else { return false }
        let lower = trimmed.lowercased()
        if lower.contains("dive center") || lower.contains("dive shop") || lower.contains(" aquatic ") {
            return true
        }
        if isIgnoredCardBoilerplate(line) { return false }
        if looksLikeLocation(trimmed) { return false }
        if wholeMatchOnly(trimmed, pattern: digitValuePattern) { return false }

        let words = trimmed.split(separator: " ").filter { !$0.isEmpty }
        if looksLikePersonName(trimmed) {
            // All-caps short labels (e.g. HOMESTEAD CRATER) are usually shops, not people.
            return trimmed == trimmed.uppercased() && (2 ... 3).contains(words.count)
        }

        let letterCount = trimmed.filter(\.isLetter).count
        return letterCount >= 4
    }

    private nonisolated static func looksLikeLocation(_ line: String) -> Bool {
        let trimmed = normalizeLine(line)
        if trimmed.filter({ $0 == "," }).count >= 1, trimmed.count >= 8 {
            return true
        }
        guard let regex = try? NSRegularExpression(pattern: locationPattern, options: [.caseInsensitive]) else {
            return false
        }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        return regex.firstMatch(in: trimmed, options: [], range: range) != nil
    }

    private nonisolated static func titleCaseName(_ line: String) -> String {
        normalizeLine(line)
            .split(separator: " ")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }
}
