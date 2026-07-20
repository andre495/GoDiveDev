import Foundation

/// Fishial.AI recognition client — v2 auth token and binary image recognition.
///
/// Flow mirrors [Fishial API v2 reference](https://docs.fishial.ai/api/api_reference).
///
/// **Security (Phase 3):** `ClientSecret` ships in the IPA until a proxy exists
/// (`cursor/owasp_secrets_handling.md`). Bearer tokens stay **in memory only** — never log
/// `Authorization`, `client_secret`, or access tokens.
final class FishialAPIClient: @unchecked Sendable {

    struct Configuration: Sendable {
        var credentials: FishialSecretsBootstrap.Credentials
        var authURL = URL(string: "https://api-recognition.fishial.ai/v2/auth")!
        var recognizeURL = URL(string: "https://api-recognition.fishial.ai/v2/recognize")!
        /// Refresh the bearer token slightly before Fishial's 10-minute expiry.
        var accessTokenLifetime: TimeInterval = 9 * 60
        /// Client-side spacing between recognize calls (portal rate-limit hygiene).
        var minimumRecognizeInterval: TimeInterval = 1.0
    }

    private let configuration: Configuration
    private let session: any FishialURLSessioning
    private let tokenLock = NSLock()
    private var cachedAccessToken: String?
    private var cachedAccessTokenFetchedAt: Date?
    private var lastRecognizeAt: Date?

    nonisolated init(
        configuration: Configuration,
        session: any FishialURLSessioning = URLSession.shared
    ) {
        self.configuration = configuration
        self.session = session
    }

    nonisolated convenience init?(
        session: any FishialURLSessioning = URLSession.shared
    ) {
        guard let credentials = FishialSecretsBootstrap.loadCredentials() else { return nil }
        self.init(
            configuration: Configuration(credentials: credentials),
            session: session
        )
    }

    /// Uploads one JPEG and returns the raw Fishial recognition payload.
    func recognizeJPEG(
        _ jpegData: Data,
        observationCoordinate: DiveCoordinate? = nil
    ) async throws -> FishialRecognitionResponse {
        let accessToken = try await fetchAccessToken()
        return try await recognizeImage(
            jpegData,
            accessToken: accessToken,
            observationCoordinate: observationCoordinate
        )
    }

    /// Runs recognition on multiple JPEG frames and merges species candidates.
    func recognizeJPEGFrames(
        _ frames: [Data],
        observationCoordinate: DiveCoordinate? = nil
    ) async throws -> [FishialRecognitionPresentation.RankedSpecies] {
        guard !frames.isEmpty else { return [] }
        var responses: [FishialRecognitionResponse] = []
        responses.reserveCapacity(frames.count)
        for frame in frames {
            let response = try await recognizeJPEG(frame, observationCoordinate: observationCoordinate)
            if !response.objects.isEmpty {
                responses.append(response)
            }
        }
        return FishialRecognitionPresentation.rankedSpecies(merging: responses)
    }

    // MARK: - Auth

    private func fetchAccessToken() async throws -> String {
        let cached = tokenLock.withLock { () -> String? in
            guard let cachedAccessToken,
                  let cachedAccessTokenFetchedAt,
                  Date().timeIntervalSince(cachedAccessTokenFetchedAt) < configuration.accessTokenLifetime
            else {
                return nil
            }
            return cachedAccessToken
        }
        if let cached { return cached }

        var request = URLRequest(url: configuration.authURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "client_id": configuration.credentials.clientID,
            "client_secret": configuration.credentials.clientSecret,
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try validateHTTP(response: response, endpoint: "v2/auth")
        let tokenResponse = try JSONDecoder().decode(AuthTokenResponse.self, from: data)
        guard let accessToken = tokenResponse.accessToken, !accessToken.isEmpty else {
            throw FishialAPIError.invalidResponse
        }

        tokenLock.withLock {
            cachedAccessToken = accessToken
            cachedAccessTokenFetchedAt = Date()
        }
        return accessToken
    }

    private struct AuthTokenResponse: Decodable {
        let accessToken: String?

        private enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
        }
    }

    // MARK: - Recognition

    private func recognizeImage(
        _ jpegData: Data,
        accessToken: String,
        observationCoordinate: DiveCoordinate?
    ) async throws -> FishialRecognitionResponse {
        try await waitForRecognizeRateLimit()

        var request = URLRequest(url: configuration.recognizeURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        if let observationCoordinate,
           DiveMapCoordinateResolver.isUsable(observationCoordinate) {
            request.setValue(
                FishialObservationLocation.locationHeaderValue(for: observationCoordinate),
                forHTTPHeaderField: "Fishial-Location-Lat-Lon"
            )
        }
        request.httpBody = jpegData

        let (data, response) = try await session.data(for: request)
        tokenLock.withLock { lastRecognizeAt = Date() }
        try validateHTTP(response: response, endpoint: "v2/recognize")

        let recognitionResponse = try JSONDecoder().decode(FishialRecognitionResponse.self, from: data)
        guard recognitionResponse.ok else {
            throw FishialAPIError.recognitionFailed(
                code: recognitionResponse.error,
                message: recognitionResponse.message
            )
        }
        return recognitionResponse
    }

    private func waitForRecognizeRateLimit() async throws {
        let delay: TimeInterval? = tokenLock.withLock {
            guard let lastRecognizeAt else { return nil }
            let elapsed = Date().timeIntervalSince(lastRecognizeAt)
            let remaining = configuration.minimumRecognizeInterval - elapsed
            return remaining > 0 ? remaining : nil
        }
        if let delay {
            try await Task.sleep(for: .seconds(delay))
        }
    }

    private func validateHTTP(response: URLResponse, endpoint: String) throws {
        guard let http = response as? HTTPURLResponse else {
            throw FishialAPIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw FishialAPIError.httpFailure(statusCode: http.statusCode, endpoint: endpoint)
        }
    }
}
