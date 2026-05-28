import SwiftUI

/// Shared oval outline chip for activity tags (logbook search + dive map tab).
struct ActivityTagOvalChipLabel: View {
    let title: String
    var isEmphasized: Bool = false

    var body: some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(AppTheme.Colors.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                Capsule(style: .continuous)
                    .strokeBorder(
                        isEmphasized
                            ? AppTheme.Colors.accent.opacity(0.65)
                            : AppTheme.Colors.tabUnselected.opacity(0.35),
                        lineWidth: isEmphasized ? 1.5 : 1
                    )
            }
    }
}
