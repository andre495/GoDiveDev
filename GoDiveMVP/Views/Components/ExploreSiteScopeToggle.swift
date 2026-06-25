import SwiftUI

/// Compact **My Sites / All Sites** control for **Explore** — icon + title per segment, Liquid Glass shell.
struct ExploreSiteScopeToggle: View {
    @Binding var selection: ExploreSiteScope

    private let segmentCornerRadius: CGFloat = 8
    private let shellCornerRadius: CGFloat = 12

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ExploreSiteScope.allCases) { scope in
                segmentButton(for: scope)
            }
        }
        .padding(4)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: shellCornerRadius))
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Dive site catalog scope")
        .accessibilityIdentifier("Explore.SiteScope")
    }

    private func segmentButton(for scope: ExploreSiteScope) -> some View {
        let isSelected = selection == scope

        return Button {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selection = scope
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: scope.systemImage)
                    .font(.caption.weight(.semibold))
                Text(scope.shortTitle)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .foregroundStyle(isSelected ? AppTheme.Colors.tabSelected : AppTheme.Colors.tabUnselected)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: segmentCornerRadius, style: .continuous)
                        .fill(AppTheme.Colors.surfaceElevated.opacity(0.92))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(scope.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("Explore.SiteScope.\(scope.rawValue)")
    }
}

/// Centered **My Sites / All Sites** control pinned above the root tab bar on **Explore**.
struct ExploreSiteScopeBottomChrome: View {
    @Binding var selection: ExploreSiteScope

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            ExploreSiteScopeToggle(selection: $selection)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
}

/// **My Sites / All Sites** pinned just above the keyboard during Explore site search.
struct ExploreSiteScopeKeyboardChrome: View {
    @Binding var selection: ExploreSiteScope

    var body: some View {
        ExploreSiteScopeBottomChrome(selection: $selection)
            .padding(.top, AppTheme.Spacing.sm)
            .padding(.bottom, AppTheme.Spacing.sm)
    }
}
