import Foundation
import WeatherKit

/// Maps WeatherKit / WeatherDaemon errors to user-facing load failure reasons.
enum ActivityWeatherKitErrorMapping: Sendable {
    nonisolated static func failureReason(for error: Error) -> ActivityWeatherConditionsPresentation.LoadFailureReason {
        if let weatherError = error as? WeatherError {
            switch weatherError {
            case .permissionDenied:
                return .permissionDenied
            case .unknown:
                break
            @unknown default:
                break
            }
        }

        let nsError = error as NSError
        if isWeatherAuthenticationFailure(nsError) {
            return .permissionDenied
        }

        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorTimedOut,
                NSURLErrorCannotFindHost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorDNSLookupFailed:
                return .network
            default:
                break
            }
        }

        let description = error.localizedDescription.lowercased()
        if description.contains("jwt") || description.contains("weatherdaemon") {
            return .permissionDenied
        }

        return .generic
    }

    private nonisolated static func isWeatherAuthenticationFailure(_ error: NSError) -> Bool {
        if error.domain.contains("WDSJWTAuthenticator") || error.domain.contains("WeatherDaemon") {
            return true
        }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isWeatherAuthenticationFailure(underlying)
        }
        return false
    }
}
