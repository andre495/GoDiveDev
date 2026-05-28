import SwiftUI

/// **Tags** section header with optional trailing actions (e.g. **Manage**, **Clear**).
struct ActivityTagsSectionHeader<Trailing: View>: View {
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "tag")
                .font(.caption.weight(.semibold))
            Text("Tags")
                .font(.caption.weight(.semibold))
            Spacer(minLength: AppTheme.Spacing.sm)
            trailing()
        }
        .foregroundStyle(AppTheme.Colors.tabUnselected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tags")
    }
}

extension ActivityTagsSectionHeader where Trailing == EmptyView {
    init() {
        self.trailing = { EmptyView() }
    }
}

/// Bordered **Tags** section card (logbook chrome or dive map overview).
struct ActivityTagsOutlinedSection<Trailing: View, Content: View>: View {
    var appliesLogbookOuterMargins: Bool
    @ViewBuilder let trailingHeader: () -> Trailing
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            ActivityTagsSectionHeader(trailing: trailingHeader)
            content()
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.Colors.tabUnselected.opacity(0.12), lineWidth: 1)
        }
        .modifier(LogbookTagsSectionOuterMargins(enabled: appliesLogbookOuterMargins))
    }
}

private struct LogbookTagsSectionOuterMargins: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.bottom, AppTheme.Spacing.sm)
        } else {
            content
        }
    }
}
