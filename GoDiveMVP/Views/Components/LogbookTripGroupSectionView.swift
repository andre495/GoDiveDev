import SwiftUI

enum LogbookTripGroupChrome {
    static let railWidth: CGFloat = 10
    static let railLineWidth: CGFloat = 2.5
    static let titleNodeDiameter: CGFloat = 10
    static let titleNodeTopInset: CGFloat = 5

    static func accentColor(for group: LogbookTripGroupDisplayData) -> Color {
        LogbookTripGroupAccentPalette.color(at: group.accentColorIndex)
    }
}

struct LogbookTripGroupHeaderView: View, Equatable {
    let group: LogbookTripGroupDisplayData
    let onOpenTrip: (UUID) -> Void

    static func == (lhs: LogbookTripGroupHeaderView, rhs: LogbookTripGroupHeaderView) -> Bool {
        lhs.group == rhs.group
    }

    private var accentColor: Color {
        LogbookTripGroupChrome.accentColor(for: group)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                onOpenTrip(group.tripID)
            } label: {
                Text(LogbookTripGrouping.formattedGroupHeaderTitle(
                    displayTitle: group.title,
                    diveCount: group.dives.count
                ))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accentColor)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("Logbook.TripGroup.TitleLink.\(group.tripID.uuidString)")

            Text(group.dateRangeLine)
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(LogbookTripGrouping.formattedGroupHeaderTitle(displayTitle: group.title, diveCount: group.dives.count)), \(group.dateRangeLine)"
        )
        .accessibilityHint("Opens trip overview")
        .accessibilityIdentifier("Logbook.TripGroup.\(group.tripID.uuidString)")
    }
}

/// Trip title link + standard logbook dive tiles with a trailing accent rail.
struct LogbookTripGroupedDivesView: View, Equatable {
    let group: LogbookTripGroupDisplayData
    let onOpenTrip: (UUID) -> Void
    let onOpenDive: (UUID) -> Void
    let onSelectMediaPreview: (DiveLogbookRowDisplayData) -> Void

    static func == (lhs: LogbookTripGroupedDivesView, rhs: LogbookTripGroupedDivesView) -> Bool {
        lhs.group == rhs.group
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                LogbookTripGroupHeaderView(group: group, onOpenTrip: onOpenTrip)

                VStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(group.dives, id: \.id) { row in
                        Button {
                            onOpenDive(row.id)
                        } label: {
                            LogbookActivityRow(
                                data: row,
                                onTapMediaPreview: row.previewMediaPhotoID == nil
                                    ? nil
                                    : { onSelectMediaPreview(row) }
                            )
                            .equatable()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            LogbookTripGroupRightRail(accentColor: LogbookTripGroupChrome.accentColor(for: group))
        }
        .accessibilityIdentifier("Logbook.TripGroup.Container.\(group.tripID.uuidString)")
    }
}

private struct LogbookTripGroupRightRail: View {
    let accentColor: Color

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(accentColor)
                .frame(
                    width: LogbookTripGroupChrome.titleNodeDiameter,
                    height: LogbookTripGroupChrome.titleNodeDiameter
                )
                .padding(.top, LogbookTripGroupChrome.titleNodeTopInset)

            Rectangle()
                .fill(accentColor)
                .frame(width: LogbookTripGroupChrome.railLineWidth)
                .frame(maxHeight: .infinity)
        }
        .frame(width: LogbookTripGroupChrome.railWidth)
        .accessibilityHidden(true)
    }
}
