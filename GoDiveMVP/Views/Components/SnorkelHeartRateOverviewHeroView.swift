import SwiftUI

/// Full-bleed hero behind the snorkel **heart rate** tab — edge-to-edge BPM profile chart
/// (same band geometry as the tank depth plot).
struct SnorkelHeartRateOverviewHeroView: View {
    let samples: [SnorkelHeartRateProfileSample]
    var sessionMaxBPMHint: Int?
    var layoutSize: CGSize
    var layoutHeight: CGFloat
    var bottomContentMargin: CGFloat = 0
    var topObstructionHeight: CGFloat = 0
    var sheetDetent: DiveActivityOverviewDetent = .large

    @State private var scrubCallout: SnorkelHeartRateScrubCallout?

    private var isLandscape: Bool {
        DiveTankOverviewHeroPresentation.isLandscapeLayout(layoutSize: layoutSize)
    }

    private var chartFrame: CGRect {
        SnorkelHeartRateOverviewHeroPresentation.chartFrame(
            layoutSize: layoutSize,
            layoutHeight: layoutHeight,
            topObstructionHeight: topObstructionHeight,
            bottomContentMargin: bottomContentMargin,
            sheetDetent: sheetDetent,
            isLandscape: isLandscape
        )
    }

    var body: some View {
        let frame = chartFrame

        ZStack {
            AppTheme.Colors.screenBackgroundGradient
                .ignoresSafeArea()

            SnorkelHeartRateProfileChart(
                samples: samples,
                sessionMaxBPMHint: sessionMaxBPMHint,
                topEdgeFadeFraction: isLandscape
                    ? 0
                    : SnorkelHeartRateOverviewHeroPresentation.portraitChartTopFadeFraction,
                pinsScrubCalloutUnderTabMenu: true,
                onScrubCalloutChange: { scrubCallout = $0 }
            )
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .accessibilityIdentifier("SnorkelOverview.HeartRateChart")

            if let scrubCallout {
                SnorkelHeartRateScrubCalloutLabel(callout: scrubCallout)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(
                        .top,
                        SnorkelHeartRateOverviewHeroPresentation.scrubCalloutTopPadding(
                            topObstructionHeight: topObstructionHeight
                        )
                    )
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
