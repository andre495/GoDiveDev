import SwiftUI

/// Segmented logbook / all-sites control for **Explore**.
struct ExploreSiteScopeToggle: View {
    @Binding var selection: ExploreSiteScope

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ExploreSiteScope.allCases) { scope in
                Button {
                    selection = scope
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: scope.systemImage)
                            .font(.caption.weight(.semibold))
                        Text(scope.shortTitle)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 36)
                    .foregroundStyle(
                        selection == scope
                            ? AppTheme.Colors.textPrimary
                            : AppTheme.Colors.tabUnselected
                    )
                    .background {
                        if selection == scope {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(AppTheme.Colors.surfaceElevated)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(scope.accessibilityLabel)
                .accessibilityAddTraits(selection == scope ? .isSelected : [])
                .accessibilityIdentifier("Explore.SiteScope.\(scope.rawValue)")
            }
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.tabUnselected.opacity(0.12))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Dive site catalog scope")
    }
}
