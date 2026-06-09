import Foundation

/// Loads Fishial.AI developer API credentials from gitignored **`Config/FishialSecrets.plist`**.
///
/// Obtain keys at [portal.fishial.ai](https://portal.fishial.ai) → About → for developers.
/// Add **`Config/FishialSecrets.plist`** with **`ClientID`** and **`ClientSecret`** (gitignored).
enum FishialSecretsBootstrap {

    struct Credentials: Equatable, Sendable {
        let clientID: String
        let clientSecret: String
    }

    nonisolated private static let secretsPlistName = "FishialSecrets"
    nonisolated private static let clientIDKey = "ClientID"
    nonisolated private static let clientSecretKey = "ClientSecret"

    nonisolated static func loadCredentials() -> Credentials? {
        guard let url = Bundle.main.url(forResource: secretsPlistName, withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let clientID = plist[clientIDKey] as? String,
              let clientSecret = plist[clientSecretKey] as? String
        else {
            return nil
        }
        return validatedCredentials(clientID: clientID, clientSecret: clientSecret)
    }

    nonisolated static func validatedCredentials(
        clientID: String,
        clientSecret: String
    ) -> Credentials? {
        let trimmedID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty,
              !trimmedSecret.isEmpty,
              !trimmedID.hasPrefix("YOUR_"),
              !trimmedSecret.hasPrefix("YOUR_")
        else {
            return nil
        }
        return Credentials(clientID: trimmedID, clientSecret: trimmedSecret)
    }

    nonisolated static var isConfigured: Bool {
        loadCredentials() != nil
    }
}
