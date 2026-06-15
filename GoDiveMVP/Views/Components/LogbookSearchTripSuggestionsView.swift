import SwiftUI

/// Suggested trip filters under the logbook search field (oval outline buttons).
struct LogbookSearchTripSuggestionsView: View {
    let suggestions: [LogbookTripSearchSuggestion]
    let onSelect: (LogbookTripSearchSuggestion) -> Void

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: AppTheme.Spacing.sm)]

    var body: some View {
        LogbookTripFilterOutlinedSection(trailingHeader: { EmptyView() }) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: AppTheme.Spacing.sm) {
                ForEach(suggestions) { suggestion in
                    Button {
                        onSelect(suggestion)
                    } label: {
                        ActivityTagOvalChipLabel(title: suggestion.displayTitle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("Logbook.TripSuggestion.\(suggestion.id)")
                    .accessibilityLabel("Filter by trip \(suggestion.displayTitle)")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Logbook.TripSuggestions")
    }
}

/// Confirmed trip filter with clear control inside the **Trips** section card.
struct LogbookActiveTripFilterChip: View {
    let displayTitle: String
    let onClear: () -> Void

    var body: some View {
        LogbookTripFilterOutlinedSection {
            Button("Clear", action: onClear)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabSelected)
        } content: {
            HStack(spacing: AppTheme.Spacing.sm) {
                ActivityTagOvalChipLabel(title: displayTitle, isEmphasized: true)
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("Logbook.ActiveTripFilter")
        .accessibilityLabel("Filtering by trip \(displayTitle)")
    }
}

/// **Trips** section header for logbook filter chips.
private struct LogbookTripsSectionHeader<Trailing: View>: View {
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "airplane")
                .font(.caption.weight(.semibold))
            Text("Trips")
                .font(.caption.weight(.semibold))
            Spacer(minLength: AppTheme.Spacing.sm)
            trailing()
        }
        .foregroundStyle(AppTheme.Colors.tabUnselected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Trips")
    }
}

/// Bordered **Trips** section card (logbook search chrome).
private struct LogbookTripFilterOutlinedSection<Trailing: View, Content: View>: View {
    @ViewBuilder let trailingHeader: () -> Trailing
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            LogbookTripsSectionHeader(trailing: trailingHeader)
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
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.bottom, AppTheme.Spacing.sm)
    }
}
