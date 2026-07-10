import CoreGraphics
import Foundation
import ImageIO
import Vision
#if canImport(UIKit)
import UIKit
#endif

/// On-device Vision OCR for certification card photos.
enum CertificationCardTextRecognition: Sendable {
    nonisolated static func parsePADICard(from imageData: Data, photoLabel: String = "Card") async -> PADICertificationCardParseResult? {
        guard let lines = try? await recognizeLines(from: imageData, photoLabel: photoLabel) else { return nil }
        let parsed = PADICertificationCardParser.parse(recognizedLines: lines)
        CertificationCardOCRDebug.parseResult(parsed, photoLabel: photoLabel)
        return parsed
    }

    /// Back-compat name used by the certification form.
    nonisolated static func parsePADIBackCard(from imageData: Data) async -> PADICertificationCardParseResult? {
        await parsePADICard(from: imageData, photoLabel: "Card")
    }

    nonisolated static func recognizeLines(from imageData: Data, photoLabel: String = "Card") async throws -> [String] {
        try await Task.detached(priority: .userInitiated) {
            try recognizeLinesSync(from: imageData, photoLabel: photoLabel)
        }.value
    }

    #if canImport(UIKit)
    private nonisolated static func recognizeLinesSync(from imageData: Data, photoLabel: String) throws -> [String] {
        guard let image = UIImage(data: imageData), let cgImage = image.cgImage else {
            CertificationCardOCRDebug.beganScan(photoLabel: photoLabel, imagePixelSize: "unreadable")
            CertificationCardOCRDebug.recognizedLines([], photoLabel: photoLabel)
            return []
        }

        let pixelSize = "\(cgImage.width)x\(cgImage.height) orient=\(image.imageOrientation.rawValue)"
        CertificationCardOCRDebug.beganScan(photoLabel: photoLabel, imagePixelSize: pixelSize)

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: visionOrientation(for: image),
            options: [:]
        )
        try handler.perform([request])

        let observations = request.results ?? []
        let lines = groupedLines(from: observations)
        CertificationCardOCRDebug.recognizedLines(lines, photoLabel: photoLabel)
        return lines
    }

    private nonisolated static func visionOrientation(for image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        case .upMirrored: .upMirrored
        case .downMirrored: .downMirrored
        case .leftMirrored: .leftMirrored
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }

    private nonisolated static func groupedLines(from observations: [VNRecognizedTextObservation]) -> [String] {
        let words: [RecognizedWord] = observations.compactMap { observation in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            let box = observation.boundingBox
            return RecognizedWord(text: text, midY: box.midY, minX: box.minX)
        }

        guard !words.isEmpty else { return [] }

        let sorted = words.sorted { lhs, rhs in
            if abs(lhs.midY - rhs.midY) > 0.015 {
                return lhs.midY > rhs.midY
            }
            return lhs.minX < rhs.minX
        }

        var lines: [String] = []
        var currentLine: [RecognizedWord] = []
        var currentY: CGFloat?

        for word in sorted {
            if let currentY, abs(word.midY - currentY) > 0.015 {
                lines.append(joinLine(currentLine))
                currentLine = []
            }
            currentLine.append(word)
            currentY = word.midY
        }

        if !currentLine.isEmpty {
            lines.append(joinLine(currentLine))
        }

        return lines
    }

    private nonisolated static func joinLine(_ words: [RecognizedWord]) -> String {
        words
            .sorted { $0.minX < $1.minX }
            .map(\.text)
            .joined(separator: " ")
    }
    #else
    private nonisolated static func recognizeLinesSync(from imageData: Data, photoLabel: String) throws -> [String] {
        []
    }
    #endif
}

#if canImport(UIKit)
private struct RecognizedWord: Sendable {
    let text: String
    let midY: CGFloat
    let minX: CGFloat
}
#endif
