import SwiftUI

/// Shared oval outline chip for activity tags (logbook search + dive map tab).
struct ActivityTagOvalChipLabel: View {
    let title: String
    var isEmphasized: Bool = false
    var isCompact: Bool = false

    var body: some View {
        Text(title)
            .font(isCompact ? .caption2.weight(.medium) : .caption.weight(.medium))
            .foregroundStyle(AppTheme.Colors.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, isCompact ? 10 : 12)
            .padding(.vertical, isCompact ? 4 : 7)
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
