import SwiftUI

/// Indeterminate loading chrome: SF Symbol clockwise arrows with repeating **`.rotate`**.
/// Prefer this over bare **`ProgressView()`** for in-app waits (Buddy Feed refresh, page loads, media).
struct GoDiveRotateLoadingIndicator: View {
    enum Size: Sendable {
        /// Media placeholders / inline row chrome.
        case compact
        /// Sheets and page-level waits.
        case regular
        /// Launch / full-screen seeding.
        case large
    }

    var size: Size = .regular
    var tint: Color = AppTheme.Colors.accent
    var isActive: Bool = true
    var accessibilityLabel: String = GoDiveRotateLoadingPresentation.defaultAccessibilityLabel
    var accessibilityIdentifier: String? = nil

    var body: some View {
        Image(systemName: GoDiveRotateLoadingPresentation.symbolName)
            .font(font)
            .foregroundStyle(tint)
            .symbolEffect(
                .rotate,
                options: .repeating.speed(GoDiveRotateLoadingPresentation.rotateSpeed),
                isActive: isActive
            )
            .accessibilityLabel(accessibilityLabel)
            .modifier(OptionalAccessibilityIdentifier(accessibilityIdentifier))
    }

    private var font: Font {
        switch size {
        case .compact:
            .body.weight(.semibold)
        case .regular:
            .title2.weight(.semibold)
        case .large:
            .title.weight(.semibold)
        }
    }
}

/// Shared tokens for **`GoDiveRotateLoadingIndicator`** / Buddy Feed pull-to-refresh.
enum GoDiveRotateLoadingPresentation: Sendable {
    nonisolated static let symbolName = "arrow.trianglehead.2.clockwise"
    nonisolated static let rotateSpeed: Double = 0.9
    nonisolated static let defaultAccessibilityLabel = "Loading"
    nonisolated static let defaultAccessibilityIdentifier = "GoDive.RotateLoadingIndicator"
}

private struct OptionalAccessibilityIdentifier: ViewModifier {
    let identifier: String?

    init(_ identifier: String?) {
        self.identifier = identifier
    }

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}
