import Foundation

/// Helpers so untrusted / API strings never go through SwiftUI **`LocalizedStringKey`** Markdown.
enum GoDivePlainText: Sendable {

    /// Builds a **`Text`**-safe string for display. Callers should pass the result to
    /// **`Text(verbatim:)`** (or **`Text(stringVar)`** where `stringVar` is already `String`).
    nonisolated static func labeled(_ label: String, value: String) -> String {
        "\(label)\(value)"
    }
}
