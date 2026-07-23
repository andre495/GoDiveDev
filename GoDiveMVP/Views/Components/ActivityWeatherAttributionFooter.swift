import SwiftUI
import WeatherKit

/// Apple Weather legal attribution (required when showing WeatherKit data).
struct ActivityWeatherAttributionFooter: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var attribution: WeatherKit.WeatherAttribution?

    var body: some View {
        Group {
            if let attribution {
                Link(destination: attribution.legalPageURL) {
                    HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                        AsyncImage(url: markURL(for: attribution)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                            default:
                                Color.clear
                            }
                        }
                        .frame(height: 14)
                        .accessibilityHidden(true)

                        Text(attribution.legalAttributionText)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.Colors.tabUnselected)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityIdentifier("ActivityOverview.WeatherAttribution")
            }
        }
        .task {
            attribution = try? await WeatherService.shared.attribution
        }
    }

    private func markURL(for attribution: WeatherKit.WeatherAttribution) -> URL {
        colorScheme == .dark ? attribution.combinedMarkDarkURL : attribution.combinedMarkLightURL
    }
}
