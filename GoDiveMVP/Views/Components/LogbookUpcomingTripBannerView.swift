import SwiftUI

/// Compact logbook shout-out for the next upcoming trip.
struct LogbookUpcomingTripBannerView: View {
    let data: LogbookUpcomingTripBannerData

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            Image(systemName: "airplane.departure")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.accent)
                .frame(width: 28, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(data.eyebrow)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.accent)

                Text(data.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(data.dateLine)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .padding(.top, 2)
                .accessibilityHidden(true)
        }
        .padding(AppTheme.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.Colors.accent.opacity(0.28), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(data.eyebrow), \(data.displayTitle), \(data.dateLine)")
        .accessibilityIdentifier("Logbook.UpcomingTripBanner")
    }
}
