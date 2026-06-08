import SwiftUI

/// Tappable overview row — ellipsis indicates the field can be edited.
struct DiveActivityEditableRow: View {
    let label: String
    let value: String
    var showsLabel: Bool = true
    var signaturePreviewData: Data?
    let isEditable: Bool
    let action: () -> Void

    private var showsSignaturePreview: Bool {
        DiveSignatureDataFormatting.hasDisplayableContent(signaturePreviewData)
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    if showsLabel {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.tabUnselected)
                    }
                    if showsSignaturePreview, let signaturePreviewData {
                        DiveSignaturePreview(data: signaturePreviewData)
                    } else {
                        Text(value)
                            .font(.body)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isEditable {
                    Image(systemName: "ellipsis")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.tabSelected)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEditable)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isEditable ? .isButton : [])
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint(isEditable ? "Edit" : "")
    }

    private var accessibilityLabelText: String {
        if showsSignaturePreview {
            return "\(label), signature on file"
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "—" {
            return label
        }
        return "\(label), \(trimmed)"
    }
}
