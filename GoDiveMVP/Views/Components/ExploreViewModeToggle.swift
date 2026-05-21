import SwiftUI

enum ExploreViewMode: String, CaseIterable, Identifiable {
    case map
    case list

    var id: String { rawValue }

    var accessibilityLabel: String {
        switch self {
        case .map: "Map"
        case .list: "List"
        }
    }

    var systemImage: String {
        switch self {
        case .map: "map.fill"
        case .list: "list.bullet"
        }
    }
}

/// Segmented map / list control for **Explore** (aligned with top-trailing chrome).
struct ExploreViewModeToggle: View {
    @Binding var selection: ExploreViewMode

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ExploreViewMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    Image(systemName: mode.systemImage)
                        .font(.body.weight(.semibold))
                        .frame(width: 40, height: 36)
                        .foregroundStyle(
                            selection == mode
                                ? AppTheme.Colors.textPrimary
                                : AppTheme.Colors.tabUnselected
                        )
                        .background {
                            if selection == mode {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(AppTheme.Colors.surfaceElevated)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mode.accessibilityLabel)
                .accessibilityAddTraits(selection == mode ? .isSelected : [])
                .accessibilityIdentifier("Explore.ViewMode.\(mode.rawValue.capitalized)")
            }
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.tabUnselected.opacity(0.12))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Explore view")
    }
}
