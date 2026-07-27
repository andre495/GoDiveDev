import SwiftUI

/// Tank-tab-style depth profile for friend-visible dive projections (depth + optional gas overlay).
struct FriendSharedDepthProfileChartView: View {
    let dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    var allowsInteraction: Bool = false
    var animatesWaterFill: Bool = true
    var chromeStyle: DiveDepthProfileChartPresentation.ChromeStyle = .standard
    var topEdgeFadeFraction: CGFloat = 0
    var topObstructionHeight: CGFloat = 0
    var pinsScrubCalloutUnderTabMenu = false
    @Binding var activeScrubCallout: DiveDepthProfileScrubCallout?

    @State private var chartSeries = GoDiveSharedDiveProjectionMapping.FriendSharedDepthChartSeries.empty

    init(
        dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive,
        allowsInteraction: Bool = false,
        animatesWaterFill: Bool = true,
        chromeStyle: DiveDepthProfileChartPresentation.ChromeStyle = .standard,
        topEdgeFadeFraction: CGFloat = 0,
        topObstructionHeight: CGFloat = 0,
        pinsScrubCalloutUnderTabMenu: Bool = false,
        activeScrubCallout: Binding<DiveDepthProfileScrubCallout?> = .constant(nil)
    ) {
        self.dive = dive
        self.allowsInteraction = allowsInteraction
        self.animatesWaterFill = animatesWaterFill
        self.chromeStyle = chromeStyle
        self.topEdgeFadeFraction = topEdgeFadeFraction
        self.topObstructionHeight = topObstructionHeight
        self.pinsScrubCalloutUnderTabMenu = pinsScrubCalloutUnderTabMenu
        _activeScrubCallout = activeScrubCallout
    }

    var body: some View {
        Group {
            if chartSeries.hasRenderableProfile {
                DiveDepthProfileOverlayChart(
                    depthSamples: chartSeries.depthSamples,
                    pressureSamples: chartSeries.pressureSamples,
                    maxDepthHintMeters: dive.maxDepthMeters ?? 0,
                    pressureBaselinePSI: chartSeries.pressureBaselinePSI,
                    allowsZoomAndPan: false,
                    animatesWaterFill: animatesWaterFill,
                    topEdgeFadeFraction: topEdgeFadeFraction,
                    chromeStyle: chromeStyle,
                    scrubCalloutPinning: pinsScrubCalloutUnderTabMenu
                        ? .pinnedUnderTabMenu(topObstructionHeight: topObstructionHeight)
                        : .followFinger,
                    onScrubCalloutChange: pinsScrubCalloutUnderTabMenu
                        ? { activeScrubCallout = $0 }
                        : nil
                )
                .allowsHitTesting(allowsInteraction)
            } else {
                AppTheme.Colors.screenBackgroundGradient
                    .overlay {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title2)
                            .foregroundStyle(AppTheme.Colors.tabUnselected)
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: depthChartRefreshToken) {
            let dive = dive
            let series = await Task.detached {
                GoDiveSharedDiveProjectionMapping.decodedDepthChartSeries(from: dive)
            }.value
            chartSeries = series
        }
    }

    private var depthChartRefreshToken: String {
        let trackLength = dive.profileTrackBase64?.count ?? 0
        return "\(dive.id)-\(trackLength)"
    }
}
