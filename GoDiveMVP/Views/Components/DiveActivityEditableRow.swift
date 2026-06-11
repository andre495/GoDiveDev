import SwiftUI

/// Read-only overview field row (section-level edit lives in the header).
struct DiveActivityEditableRow: View {
    let label: String
    let value: String
    var showsLabel: Bool = true
    var signaturePreviewData: Data?

    private var showsSignaturePreview: Bool {
        DiveSignatureDataFormatting.hasDisplayableContent(signaturePreviewData)
    }

    var body: some View {
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
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

/// Plus / ellipsis affordance aligned with section titles in dive overview panels.
struct DiveActivitySectionHeaderActionButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabSelected)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
