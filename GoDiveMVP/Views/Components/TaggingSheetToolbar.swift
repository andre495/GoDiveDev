import SwiftUI

/// Standard tagging-sheet toolbar: Cancel · optional + · Done.
struct TaggingSheetToolbarModifier: ViewModifier {
    let cancelAccessibilityIdentifier: String
    let doneAccessibilityIdentifier: String
    var doneTitle: String = "Done"
    var plusAccessibilityIdentifier: String?
    var plusAccessibilityLabel: String?
    let onCancel: () -> Void
    let onDone: () -> Void
    var onPlus: (() -> Void)?

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .cancellationAction) {
                AppGlassToolbarCancelButton(
                    action: onCancel,
                    accessibilityIdentifier: cancelAccessibilityIdentifier
                )
            }

            if let onPlus,
               let plusAccessibilityIdentifier,
               let plusAccessibilityLabel {
                ToolbarItem(placement: .topBarTrailing) {
                    AppSheetToolbarPlusButton(
                        action: onPlus,
                        accessibilityIdentifier: plusAccessibilityIdentifier,
                        accessibilityLabel: plusAccessibilityLabel
                    )
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }

            ToolbarItem(placement: .confirmationAction) {
                AppGlassProminentDoneButton(
                    action: onDone,
                    accessibilityIdentifier: doneAccessibilityIdentifier,
                    title: doneTitle
                )
            }
        }
    }
}

extension View {
    func taggingSheetToolbar(
        cancelAccessibilityIdentifier: String,
        doneAccessibilityIdentifier: String,
        doneTitle: String = "Done",
        plusAccessibilityIdentifier: String? = nil,
        plusAccessibilityLabel: String? = nil,
        onCancel: @escaping () -> Void,
        onDone: @escaping () -> Void,
        onPlus: (() -> Void)? = nil
    ) -> some View {
        modifier(
            TaggingSheetToolbarModifier(
                cancelAccessibilityIdentifier: cancelAccessibilityIdentifier,
                doneAccessibilityIdentifier: doneAccessibilityIdentifier,
                doneTitle: doneTitle,
                plusAccessibilityIdentifier: plusAccessibilityIdentifier,
                plusAccessibilityLabel: plusAccessibilityLabel,
                onCancel: onCancel,
                onDone: onDone,
                onPlus: onPlus
            )
        )
    }
}
