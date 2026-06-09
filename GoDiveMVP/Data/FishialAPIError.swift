import Foundation

enum FishialAPIError: Error, Equatable, Sendable {
    case missingCredentials
    case invalidURL(String)
    case invalidResponse
    case httpFailure(statusCode: Int, endpoint: String)
    case recognitionFailed(code: String?, message: String?)

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Fishial API credentials are not configured."
        case .invalidURL(let endpoint):
            return "Invalid Fishial URL for \(endpoint)."
        case .invalidResponse:
            return "Unexpected Fishial API response."
        case .httpFailure(let statusCode, let endpoint):
            return "Fishial \(endpoint) failed with status \(statusCode)."
        case .recognitionFailed(_, let message):
            if let message, !message.isEmpty {
                return message
            }
            return "Fishial could not recognize fish in this image."
        }
    }
}

extension FishialAPIError: LocalizedError {}
