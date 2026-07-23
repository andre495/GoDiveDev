import SwiftUI
import WeatherKit

/// **Weather** block for dive / snorkel map overview at **large** detent (WeatherKit).
struct ActivityMapWeatherConditionsSection: View {
    let activityID: UUID
    let mapCoordinate: DiveCoordinate?
    let activityStart: Date
    let timeZoneOffsetSeconds: Int?
    let displayUnits: DiveDisplayUnitSystem
    let isSectionVisible: Bool
    /// Import-time frozen snapshot — when present, WeatherKit is not queried on open.
    var importedSnapshot: ActivityWeatherConditionsSnapshot?

    @State private var loadState: LoadState = .idle

    private enum LoadState: Equatable {
        case idle
        case loading
        case loaded(ActivityWeatherConditionsSnapshot)
        case unavailable(ActivityWeatherConditionsPresentation.UnavailableReason)
        case failed(ActivityWeatherConditionsPresentation.LoadFailureReason)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(ActivityWeatherConditionsPresentation.sectionTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabUnselected)

            sectionBody
                .padding(AppTheme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.Colors.surfaceElevated)
                }

            if showsWeatherAttribution {
                ActivityWeatherAttributionFooter()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(ActivityWeatherConditionsPresentation.sectionAccessibilityIdentifier)
        .task(id: fetchTaskToken) {
            await loadWeatherIfNeeded()
        }
    }

    private var fetchTaskToken: String {
        let importedToken = importedSnapshot.map {
            "\($0.conditionDescription)-\($0.temperatureDisplay)-\($0.symbolName)"
        } ?? "none"
        return "\(activityID.uuidString)-\(isSectionVisible)-\(importedToken)-\(displayUnits)-\(mapCoordinate?.latitude ?? 0)-\(mapCoordinate?.longitude ?? 0)-\(activityStart.timeIntervalSinceReferenceDate)"
    }

    private var showsWeatherAttribution: Bool {
        if case .loaded = loadState { return true }
        return false
    }

    @ViewBuilder
    private var sectionBody: some View {
        switch loadState {
        case .idle, .loading:
            HStack(spacing: AppTheme.Spacing.sm) {
                ProgressView()
                Text("Loading weather…")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier(ActivityWeatherConditionsPresentation.loadingAccessibilityIdentifier)
        case .unavailable(let reason):
            Text(ActivityWeatherConditionsPresentation.unavailableMessage(for: reason))
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        case .failed(let reason):
            Text(ActivityWeatherConditionsPresentation.loadFailedMessage(for: reason))
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        case .loaded(let snapshot):
            loadedContent(snapshot)
        }
    }

    @ViewBuilder
    private func loadedContent(_ snapshot: ActivityWeatherConditionsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
                Image(systemName: snapshot.symbolName)
                    .font(.title2)
                    .symbolRenderingMode(.multicolor)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.conditionDescription)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(snapshot.temperatureDisplay)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }
                Spacer(minLength: 0)
            }

            Text(snapshot.aroundEntryLine)
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.tabUnselected)

            if let dailyHighLowLine = snapshot.dailyHighLowLine {
                Text(dailyHighLowLine)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            if snapshot.humidityLine != nil || snapshot.windLine != nil {
                HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                    if let humidityLine = snapshot.humidityLine {
                        Text(humidityLine)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                    if let windLine = snapshot.windLine {
                        Text(windLine)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                }
            }
        }
    }

    @MainActor
    private func loadWeatherIfNeeded() async {
        guard isSectionVisible else {
            loadState = .idle
            return
        }
        if let importedSnapshot {
            loadState = .loaded(importedSnapshot)
            return
        }
        if let reason = ActivityWeatherConditionsPresentation.unavailableReason(
            mapCoordinate: mapCoordinate,
            activityStart: activityStart
        ) {
            loadState = .unavailable(reason)
            return
        }
        loadState = .loading
        let outcome = await ActivityWeatherKitService.fetch(
            mapCoordinate: mapCoordinate,
            activityStart: activityStart,
            timeZoneOffsetSeconds: timeZoneOffsetSeconds,
            displayUnits: displayUnits
        )
        switch outcome {
        case .loaded(let snapshot):
            loadState = .loaded(snapshot)
        case .unavailable(let reason):
            loadState = .unavailable(reason)
        case .failed(let reason):
            loadState = .failed(reason)
        }
    }
}
