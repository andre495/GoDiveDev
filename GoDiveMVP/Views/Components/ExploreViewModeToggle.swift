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

/// Single icon that switches **Explore** between map and list (shows the destination mode).
struct ExploreViewModeFlipButton: View {
    @Binding var viewMode: ExploreViewMode

    private var destinationMode: ExploreViewMode {
        viewMode == .map ? .list : .map
    }

    var body: some View {
        Button {
            viewMode = destinationMode
        } label: {
            Image(systemName: destinationMode.systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show \(destinationMode.accessibilityLabel)")
        .accessibilityIdentifier("Explore.ViewMode.FlipTo\(destinationMode.rawValue.capitalized)")
    }
}
