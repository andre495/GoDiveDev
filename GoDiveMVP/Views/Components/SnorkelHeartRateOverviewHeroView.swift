import SwiftUI

/// Full-bleed hero behind the snorkel **heart rate** tab — BPM profile chart.
struct SnorkelHeartRateOverviewHeroView: View {
    let samples: [SnorkelHeartRateProfileSample]
    var sessionMaxBPMHint: Int?
    var bottomContentMargin: CGFloat = 0
    var topObstructionHeight: CGFloat = 0

    var body: some View {
        let insets = SnorkelHeartRateOverviewHeroPresentation.chartContentInsets(
            topObstructionHeight: topObstructionHeight,
            bottomContentMargin: bottomContentMargin
        )

        ZStack {
            AppTheme.Colors.screenBackgroundGradient
                .ignoresSafeArea()

            SnorkelHeartRateProfileChart(
                samples: samples,
                sessionMaxBPMHint: sessionMaxBPMHint
            )
            .padding(.top, insets.top)
            .padding(.horizontal, insets.horizontal)
            .padding(.bottom, insets.bottom)
            .accessibilityIdentifier("SnorkelOverview.HeartRateChart")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(heroAccessibilityLabel)
    }

    private var heroAccessibilityLabel: String {
        if samples.count < 2 {
            return "Heart rate chart with no samples"
        }
        return "Heart rate chart with \(samples.count) samples"
    }
}
