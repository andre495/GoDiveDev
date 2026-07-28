import SwiftUI

/// Compact depth profile with optional yellow gas line (**PSI** above ending pressure), labeled time/depth axes, and dual scrub callout.
struct DiveDepthProfileOverlayChart: View {
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem

    let depthSamples: [DiveDepthProfileSample]
    let pressureSamples: [DiveDepthProfilePressureSample]
    var mediaMarkers: [DiveDepthProfileMediaMarker] = []
    var mediaPhotosByID: [UUID: DiveMediaPhoto] = [:]
    /// Used when depth samples are empty or max depth in samples is 0.
    var maxDepthHintMeters: Double
    /// **Y = 0** for the gas line; typically dive ending **PSI**.
    var pressureBaselinePSI: Double?
    /// **0...1** — progressive draw for depth + PSI polylines (tank **minimized** entrance).
    var profileLineRevealProgress: CGFloat = 1
    /// Opacity for depth + gas strokes and dark underfill (collapse fade while dragging).
    var profileStrokeAndUnderfillOpacity: CGFloat = 1
    /// **0…1** — fades the top half of the water fill after snap to **minimized**.
    var waterTopHalfFadeProgress: CGFloat = 0
    /// Landscape minimized profile with media markers — pinch to zoom; two-finger pan; one-finger scrub.
    var allowsZoomAndPan = false
    /// Shimmering water fill + miniature bubbles above the depth curve; static blue under the curve.
    var showsWaterFill = true
    /// Buddy-feed heroes and other compact tiles keep the fill but pause bubble / shimmer motion.
    var animatesWaterFill = true
    /// Rising bubbles in the water fill (tank **minimized** / landscape; off for portrait **large**).
    var showsWaterBubbles = true
    /// **0…1** — masks the plot top to transparent (portrait tank **minimized**).
    var topEdgeFadeFraction: CGFloat = 0
    /// Non-scrubbable side margins; profile extends flat from first/last samples (landscape tank hero).
    var horizontalEdgeBufferFraction: CGFloat = 0
    var chromeStyle: DiveDepthProfileChartPresentation.ChromeStyle = .standard
    var onMediaMarkerTap: ((DiveDepthProfileMediaMarker) -> Void)? = nil
    /// When **`.pinnedUnderTabMenu`**, the parent owns the callout via **`onScrubCalloutChange`**.
    var scrubCalloutPinning: DiveDepthProfileScrubCalloutPinning = .followFinger
    var onScrubCalloutChange: ((DiveDepthProfileScrubCallout?) -> Void)? = nil

    private static let scrubHoldDuration: Duration = .milliseconds(180)
    /// Pending finger during hold — class mutation avoids SwiftUI body invalidation before scrub activates.
    @State private var pendingFingerLocation = DiveDepthProfilePendingFingerLocation()
    @State private var scrubHoldTask: Task<Void, Never>?
    @State private var scrubActive = false
    @State private var scrubDepthIndex: Int?
    @State private var chartViewport: DiveDepthProfileChartViewport?
    @State private var panGestureLastTranslationX: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let rect = DiveDepthProfileOverlayChartLayout.plotRect(
                in: geo.size,
                chromeStyle: chromeStyle
            )
            let maxElapsed = chartMaxElapsed
            let axisMaxDepth = chartDepthAxisMaximum
            let viewport = activeViewport(fullElapsedMax: maxElapsed)
            let pressureScale = pressureDepthAlignedScale(
                displayPressureSamples: pressureSamples
            )
            let lineReveal = min(1, max(0, profileLineRevealProgress))

            ZStack(alignment: .topLeading) {
                if depthSamples.count < 2 {
                    Text("Not enough points to draw a profile.")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.Colors.tabUnselected)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    if chromeStyle == .standard {
                        axisChrome(in: rect, viewport: viewport, axisMaxDepth: axisMaxDepth)
                    }

                    DiveDepthProfileStaticPlotLayer(
                        depthSamples: depthSamples,
                        pressureSamples: pressureSamples,
                        mediaMarkers: mediaMarkers,
                        mediaPhotosByID: mediaPhotosByID,
                        rect: rect,
                        viewport: viewport,
                        axisMaxDepth: axisMaxDepth,
                        maxElapsed: maxElapsed,
                        lineReveal: lineReveal,
                        strokeAndUnderfillOpacity: min(1, max(0, profileStrokeAndUnderfillOpacity)),
                        waterTopHalfFadeProgress: min(1, max(0, waterTopHalfFadeProgress)),
                        pressureScale: pressureScale.map {
                            DiveDepthProfileStaticPlotLayer.PressureScale(
                                minDepthMeters: $0.minDepthMeters,
                                maxDepthMeters: $0.maxDepthMeters,
                                minPressurePSI: $0.minPressurePSI,
                                maxPressurePSI: $0.maxPressurePSI
                            )
                        },
                        showsWaterFill: showsWaterFill,
                        animatesWaterFill: animatesWaterFill && !scrubActive,
                        showsWaterBubbles: showsWaterBubbles,
                        showsGasOverlay: showsGasOverlay,
                        topBufferFraction: plotTopBufferFraction,
                        horizontalEdgeBufferFraction: horizontalEdgeBufferFraction,
                        onMediaMarkerTap: onMediaMarkerTap
                    )
                    .equatable()

                    if scrubActive, let idx = scrubDepthIndex, depthSamples.indices.contains(idx) {
                        scrubChrome(
                            in: rect,
                            viewport: viewport,
                            axisMaxDepth: axisMaxDepth,
                            depthIndex: idx,
                            pressureScale: pressureScale
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .mask {
                diveDepthProfileChartMask(size: geo.size, topEdgeFadeFraction: topEdgeFadeFraction)
            }
            .contentShape(Rectangle())
            .modifier(
                DiveDepthProfileOverlayChartInteractionModifier(
                    allowsZoomAndPan: allowsZoomAndPan,
                    rect: rect,
                    maxElapsed: maxElapsed,
                    horizontalEdgeBufferFraction: horizontalEdgeBufferFraction,
                    chartViewport: $chartViewport,
                    panGestureLastTranslationX: $panGestureLastTranslationX,
                    depthSampleCount: depthSamples.count,
                    pendingFingerLocation: pendingFingerLocation,
                    scrubHoldTask: $scrubHoldTask,
                    scrubActive: $scrubActive,
                    scrubDepthIndex: $scrubDepthIndex,
                    scrubHoldDuration: Self.scrubHoldDuration,
                    nearestDepthIndex: { location in
                        nearestDepthIndex(location: location, rect: rect, viewport: viewport)
                    },
                    cancelScrubHoldTask: cancelScrubHoldTask,
                    clearScrubState: clearScrubState
                )
            )
            .onAppear {
                syncViewport(fullElapsedMax: maxElapsed)
            }
            .onChange(of: maxElapsed) { _, newMax in
                syncViewport(fullElapsedMax: newMax)
            }
            .onChange(of: allowsZoomAndPan) { _, isEnabled in
                if !isEnabled {
                    chartViewport = DiveDepthProfileChartViewport.full(elapsedMax: maxElapsed)
                }
            }
            .onDisappear {
                cancelScrubHoldTask()
                clearScrubState()
            }
            .onChange(of: scrubActive) { _, _ in
                publishScrubCallout()
            }
            .onChange(of: scrubDepthIndex) { _, _ in
                publishScrubCallout()
            }
        }
    }

    private func activeViewport(fullElapsedMax: Double) -> DiveDepthProfileChartViewport {
        chartViewport ?? DiveDepthProfileChartViewport.full(elapsedMax: fullElapsedMax)
    }

    private func syncViewport(fullElapsedMax: Double) {
        if chartViewport == nil {
            chartViewport = DiveDepthProfileChartViewport.full(elapsedMax: fullElapsedMax)
        }
    }

    private var showsGasOverlay: Bool {
        guard pressureSamples.count >= 2 else { return false }
        return DiveDepthProfileOverlayChartLayout.recordedPressurePSIRange(in: pressureSamples) != nil
    }

    private var chartMaxElapsed: Double {
        let depthMax = depthSamples.last?.elapsedSeconds ?? 0
        let pressureMax = pressureSamples.last?.elapsedSeconds ?? 0
        return max(depthMax, pressureMax, 0.001)
    }

    private var chartDepthAxisMaximum: Double {
        DiveDepthProfileChartPresentation.depthAxisMaximumMeters(
            dataMaxMeters: depthSamples.map(\.depthMeters).max() ?? 0,
            hintMeters: maxDepthHintMeters
        )
    }

    private var plotTopBufferFraction: Double {
        DiveDepthProfileChartPresentation.depthAxisTopBufferFraction(for: chromeStyle)
    }

    private struct PressureDepthAlignedScale: Sendable {
        let minDepthMeters: Double
        let maxDepthMeters: Double
        let minPressurePSI: Double
        let maxPressurePSI: Double
    }

    private func pressureDepthAlignedScale(
        displayPressureSamples: [DiveDepthProfilePressureSample]
    ) -> PressureDepthAlignedScale? {
        guard let pressureRange = DiveDepthProfileOverlayChartLayout.recordedPressurePSIRange(
            in: displayPressureSamples
        ) else { return nil }
        let depthRange = DiveDepthProfileOverlayChartLayout.recordedDepthMetersRange(in: depthSamples)
        return PressureDepthAlignedScale(
            minDepthMeters: depthRange.min,
            maxDepthMeters: depthRange.max,
            minPressurePSI: pressureRange.min,
            maxPressurePSI: pressureRange.max
        )
    }

    private func axisChrome(
        in rect: CGRect,
        viewport: DiveDepthProfileChartViewport,
        axisMaxDepth: Double
    ) -> some View {
        let depthTicks = DiveDepthProfileChartAxisPresentation.depthTicks(
            maxDepthMeters: axisMaxDepth,
            system: diveDisplayUnitSystem
        )
        let axisColor = AppTheme.Colors.tabUnselected.opacity(0.55)
        let tickLength: CGFloat = 4
        let timeTicks = DiveDepthProfileChartAxisPresentation.timeTicks(viewport: viewport)

        return ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            }
            .stroke(axisColor, style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))

            ForEach(Array(depthTicks.enumerated()), id: \.offset) { _, tick in
                let point = DiveDepthProfileChartAxisPresentation.depthTickPoint(
                    depthDataFraction: tick.fraction,
                    in: rect,
                    topBufferFraction: plotTopBufferFraction
                )
                Path { path in
                    path.move(to: point)
                    path.addLine(to: CGPoint(x: point.x + tickLength, y: point.y))
                }
                .stroke(axisColor, lineWidth: 1)

                Text(tick.label)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
                    .position(x: point.x - 18, y: point.y)
            }

            ForEach(Array(timeTicks.enumerated()), id: \.offset) { _, tick in
                let point = DiveDepthProfileChartAxisPresentation.timeTickPoint(
                    fraction: tick.fraction,
                    in: rect
                )
                Path { path in
                    path.move(to: point)
                    path.addLine(to: CGPoint(x: point.x, y: point.y - tickLength))
                }
                .stroke(axisColor, lineWidth: 1)

                Text(tick.label)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
                    .position(x: point.x, y: point.y + 10)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func scrubChrome(
        in rect: CGRect,
        viewport: DiveDepthProfileChartViewport,
        axisMaxDepth: Double,
        depthIndex idx: Int,
        pressureScale: PressureDepthAlignedScale?
    ) -> some View {
        let depthSample = depthSamples[idx]
        let depthPoint = DiveDepthProfileOverlayChartLayout.depthPoint(
            sample: depthSample,
            in: rect,
            viewport: viewport,
            maxDepth: axisMaxDepth,
            topBufferFraction: plotTopBufferFraction,
            horizontalEdgeBufferFraction: horizontalEdgeBufferFraction
        )

        Path { path in
            path.move(to: CGPoint(x: depthPoint.x, y: rect.minY))
            path.addLine(to: CGPoint(x: depthPoint.x, y: rect.maxY))
        }
        .stroke(AppTheme.Colors.accent.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

        Circle()
            .fill(AppTheme.Colors.accent)
            .frame(width: 10, height: 10)
            .overlay {
                Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5)
            }
            .position(depthPoint)

        if let pressureScale,
           let pressureIndex = DiveDepthProfileOverlayChartLayout.indexNearestPressure(
               elapsedSeconds: depthSample.elapsedSeconds,
               in: pressureSamples
           ),
           pressureSamples.indices.contains(pressureIndex) {
            let pressureSample = pressureSamples[pressureIndex]
            let gasPoint = DiveDepthProfileOverlayChartLayout.pressurePoint(
                sample: pressureSample,
                in: rect,
                viewport: viewport,
                minDepthMeters: pressureScale.minDepthMeters,
                maxDepthMeters: pressureScale.maxDepthMeters,
                axisMaxDepthMeters: axisMaxDepth,
                minPressurePSI: pressureScale.minPressurePSI,
                maxPressurePSI: pressureScale.maxPressurePSI,
                topBufferFraction: plotTopBufferFraction,
                horizontalEdgeBufferFraction: horizontalEdgeBufferFraction
            )

            Circle()
                .fill(AppTheme.Colors.tankGasAccent)
                .frame(width: 10, height: 10)
                .overlay {
                    Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                }
                .position(gasPoint)
        }

        if !usesPinnedScrubCallout {
            scrubCallout(
                elapsedSeconds: depthSample.elapsedSeconds,
                depthMeters: depthSample.depthMeters,
                pressurePSI: scrubPressurePSI(for: depthSample),
                anchor: depthPoint,
                in: rect
            )
        }
    }

    private var usesPinnedScrubCallout: Bool {
        if case .pinnedUnderTabMenu = scrubCalloutPinning { return true }
        return false
    }

    private func publishScrubCallout() {
        guard usesPinnedScrubCallout else { return }
        guard let onScrubCalloutChange else { return }
        guard scrubActive,
              let idx = scrubDepthIndex,
              depthSamples.indices.contains(idx) else {
            onScrubCalloutChange(nil)
            return
        }
        let sample = depthSamples[idx]
        onScrubCalloutChange(
            DiveDepthProfileScrubCallout(
                elapsedSeconds: sample.elapsedSeconds,
                depthMeters: sample.depthMeters,
                pressurePSI: scrubPressurePSI(for: sample)
            )
        )
    }

    private func scrubPressurePSI(for depthSample: DiveDepthProfileSample) -> Double? {
        guard let index = DiveDepthProfileOverlayChartLayout.indexNearestPressure(
            elapsedSeconds: depthSample.elapsedSeconds,
            in: pressureSamples
        ) else { return nil }
        return pressureSamples[index].pressurePSI
    }

    private func scrubCallout(
        elapsedSeconds: Double,
        depthMeters: Double,
        pressurePSI: Double?,
        anchor: CGPoint,
        in rect: CGRect
    ) -> some View {
        DiveDepthProfileScrubCalloutLabel(
            callout: DiveDepthProfileScrubCallout(
                elapsedSeconds: elapsedSeconds,
                depthMeters: depthMeters,
                pressurePSI: pressurePSI
            )
        )
        .position(scrubCalloutPosition(point: anchor, pressurePresent: pressurePSI != nil, in: rect))
    }

    private func scrubCalloutPosition(point: CGPoint, pressurePresent: Bool, in rect: CGRect) -> CGPoint {
        let boxHalfW: CGFloat = 86
        let boxHalfH: CGFloat = pressurePresent ? 40 : 30
        let margin: CGFloat = 6
        let preferredY = point.y - (pressurePresent ? 56 : 48)
        let yTop = min(preferredY, point.y - margin - boxHalfH)
        let y = max(rect.minY + boxHalfH + margin, yTop)
        let x = min(max(point.x, rect.minX + boxHalfW + margin), rect.maxX - boxHalfW - margin)
        return CGPoint(x: x, y: y)
    }

    private func nearestDepthIndex(
        location: CGPoint,
        rect: CGRect,
        viewport: DiveDepthProfileChartViewport
    ) -> Int? {
        guard DiveDepthProfileOverlayChartLayout.isScrubbableChartX(
            location.x,
            in: rect,
            horizontalEdgeBufferFraction: horizontalEdgeBufferFraction
        ) else {
            return nil
        }
        guard let target = DiveDepthProfileOverlayChartLayout.elapsedSeconds(
            atChartX: location.x,
            in: rect,
            viewport: viewport,
            horizontalEdgeBufferFraction: horizontalEdgeBufferFraction
        ) else {
            return nil
        }
        return DiveDepthProfileSeries.indexNearestElapsed(target, in: depthSamples)
    }

    private func cancelScrubHoldTask() {
        scrubHoldTask?.cancel()
        scrubHoldTask = nil
    }

    private func clearScrubState() {
        pendingFingerLocation.point = nil
        scrubActive = false
        scrubDepthIndex = nil
        if usesPinnedScrubCallout {
            onScrubCalloutChange?(nil)
        }
    }

    @ViewBuilder
    private func diveDepthProfileChartMask(size: CGSize, topEdgeFadeFraction: CGFloat) -> some View {
        let fraction = min(max(topEdgeFadeFraction, 0), 1)
        if fraction > 0.001 {
            let fadeHeight = size.height * fraction
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [.clear, .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: fadeHeight)
                Rectangle().fill(.black)
            }
        } else {
            Rectangle().fill(.black)
        }
    }
}

// MARK: - Static plot (Equatable — skips O(n) path rebuilds during scrub)

private final class DiveDepthProfilePendingFingerLocation {
    var point: CGPoint?
}

/// Depth / gas / fill layers that do not depend on scrub index.
private struct DiveDepthProfileStaticPlotLayer: View, Equatable {
    struct PressureScale: Equatable, Sendable {
        let minDepthMeters: Double
        let maxDepthMeters: Double
        let minPressurePSI: Double
        let maxPressurePSI: Double
    }

    let depthSamples: [DiveDepthProfileSample]
    let pressureSamples: [DiveDepthProfilePressureSample]
    let mediaMarkers: [DiveDepthProfileMediaMarker]
    let mediaPhotosByID: [UUID: DiveMediaPhoto]
    let rect: CGRect
    let viewport: DiveDepthProfileChartViewport
    let axisMaxDepth: Double
    let maxElapsed: Double
    let lineReveal: CGFloat
    let strokeAndUnderfillOpacity: CGFloat
    let waterTopHalfFadeProgress: CGFloat
    let pressureScale: PressureScale?
    let showsWaterFill: Bool
    let animatesWaterFill: Bool
    let showsWaterBubbles: Bool
    let showsGasOverlay: Bool
    let topBufferFraction: Double
    let horizontalEdgeBufferFraction: CGFloat
    let onMediaMarkerTap: ((DiveDepthProfileMediaMarker) -> Void)?

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.rect == rhs.rect
            && lhs.viewport == rhs.viewport
            && lhs.axisMaxDepth == rhs.axisMaxDepth
            && lhs.maxElapsed == rhs.maxElapsed
            && lhs.lineReveal == rhs.lineReveal
            && lhs.strokeAndUnderfillOpacity == rhs.strokeAndUnderfillOpacity
            && lhs.waterTopHalfFadeProgress == rhs.waterTopHalfFadeProgress
            && lhs.pressureScale == rhs.pressureScale
            && lhs.showsWaterFill == rhs.showsWaterFill
            && lhs.animatesWaterFill == rhs.animatesWaterFill
            && lhs.showsWaterBubbles == rhs.showsWaterBubbles
            && lhs.showsGasOverlay == rhs.showsGasOverlay
            && lhs.topBufferFraction == rhs.topBufferFraction
            && lhs.horizontalEdgeBufferFraction == rhs.horizontalEdgeBufferFraction
            && lhs.depthSamples.count == rhs.depthSamples.count
            && lhs.depthSamples.first == rhs.depthSamples.first
            && lhs.depthSamples.last == rhs.depthSamples.last
            && lhs.pressureSamples.count == rhs.pressureSamples.count
            && lhs.pressureSamples.first == rhs.pressureSamples.first
            && lhs.pressureSamples.last == rhs.pressureSamples.last
            && lhs.mediaMarkers.count == rhs.mediaMarkers.count
            && lhs.mediaMarkers.first?.mediaID == rhs.mediaMarkers.first?.mediaID
            && lhs.mediaMarkers.last?.mediaID == rhs.mediaMarkers.last?.mediaID
    }

    var body: some View {
        let localPlotRect = CGRect(origin: .zero, size: rect.size)
        let waterFillPath = DiveDepthProfileChartPresentation.depthProfileAreaPath(
            samples: depthSamples,
            in: localPlotRect,
            viewport: viewport,
            axisMaxDepthMeters: axisMaxDepth,
            topBufferFraction: topBufferFraction,
            horizontalEdgeBufferFraction: horizontalEdgeBufferFraction
        )
        let underCurvePath = DiveDepthProfileChartPresentation.depthProfileUnderCurveAreaPath(
            samples: depthSamples,
            in: localPlotRect,
            viewport: viewport,
            axisMaxDepthMeters: axisMaxDepth,
            topBufferFraction: topBufferFraction,
            horizontalEdgeBufferFraction: horizontalEdgeBufferFraction
        )
        let linePressureSamples = DiveDepthProfileChartPresentation.downsampledPressureSamplesForLine(
            pressureSamples
        )
        let strokeOpacity = Double(min(1, max(0, strokeAndUnderfillOpacity)))

        ZStack(alignment: .topLeading) {
            if showsWaterFill {
                DiveDepthProfileChartWaterFillView(
                    areaPath: waterFillPath,
                    plotSize: rect.size,
                    revealProgress: 1,
                    animates: animatesWaterFill,
                    showsBubbles: showsWaterBubbles,
                    topHalfFadeProgress: waterTopHalfFadeProgress
                )
                .offset(x: rect.minX, y: rect.minY)
            }

            DiveDepthProfileChartStaticUnderfillView(
                areaPath: underCurvePath,
                plotSize: rect.size,
                revealProgress: lineReveal,
                opacity: strokeAndUnderfillOpacity
            )
            .offset(x: rect.minX, y: rect.minY)

            Group {
                if showsGasOverlay, let pressureScale {
                    pressurePolyline(
                        pressureSamples: linePressureSamples,
                        pressureScale: pressureScale
                    )
                }
                depthPolyline
            }
            .opacity(strokeOpacity)
            .drawingGroup()

            mediaMarkerLayer
                .opacity(Double(lineReveal) * strokeOpacity)
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .clipShape(Rectangle())
    }

    private var depthPolyline: some View {
        DiveDepthProfileChartPresentation.depthProfileLinePath(
            samples: depthSamples,
            in: rect,
            viewport: viewport,
            axisMaxDepthMeters: axisMaxDepth,
            topBufferFraction: topBufferFraction,
            horizontalEdgeBufferFraction: horizontalEdgeBufferFraction
        )
        .trim(from: 0, to: lineReveal)
        .stroke(
            AppTheme.Colors.accent,
            style: StrokeStyle(lineWidth: 2.25, lineCap: .round, lineJoin: .round)
        )
        .shadow(color: AppTheme.Colors.accentLight.opacity(0.35), radius: 2, y: 1)
    }

    private func pressurePolyline(
        pressureSamples: [DiveDepthProfilePressureSample],
        pressureScale: PressureScale
    ) -> some View {
        Path { path in
            let points = pressureSamples.map { sample in
                DiveDepthProfileOverlayChartLayout.pressurePoint(
                    sample: sample,
                    in: rect,
                    viewport: viewport,
                    minDepthMeters: pressureScale.minDepthMeters,
                    maxDepthMeters: pressureScale.maxDepthMeters,
                    axisMaxDepthMeters: axisMaxDepth,
                    minPressurePSI: pressureScale.minPressurePSI,
                    maxPressurePSI: pressureScale.maxPressurePSI,
                    topBufferFraction: topBufferFraction,
                    horizontalEdgeBufferFraction: horizontalEdgeBufferFraction
                )
            }
            let traced = DiveDepthProfileOverlayChartLayout.tracedProfilePath(
                points: points,
                in: rect,
                horizontalEdgeBufferFraction: horizontalEdgeBufferFraction,
                extendsIntoHorizontalBuffers: false
            )
            path.addPath(traced)
        }
        .trim(from: 0, to: lineReveal)
        .stroke(
            AppTheme.Colors.tankGasAccent,
            style: StrokeStyle(lineWidth: 2.25, lineCap: .round, lineJoin: .round)
        )
    }

    private var mediaMarkerLayer: some View {
        let markerThumbnailSize = DiveDepthProfileMediaPlotting.markerThumbnailDisplaySize(
            viewport: viewport,
            fullElapsedMax: maxElapsed
        )

        return Group {
            ForEach(mediaMarkers) { marker in
                if viewport.contains(elapsedSeconds: marker.elapsedSeconds),
                   let media = mediaPhotosByID[marker.mediaID] {
                    Button {
                        onMediaMarkerTap?(marker)
                    } label: {
                        DiveDepthProfileMediaMarkerView(
                            media: media,
                            thumbnailSize: markerThumbnailSize
                        )
                    }
                    .buttonStyle(.plain)
                    .position(
                        DiveDepthProfileOverlayChartLayout.depthPoint(
                            sample: DiveDepthProfileSample(
                                elapsedSeconds: marker.elapsedSeconds,
                                depthMeters: marker.depthMeters
                            ),
                            in: rect,
                            viewport: viewport,
                            maxDepth: axisMaxDepth,
                            topBufferFraction: topBufferFraction,
                            horizontalEdgeBufferFraction: horizontalEdgeBufferFraction
                        )
                    )
                    .accessibilityIdentifier("DiveDepthProfileOverlayChart.MediaMarker.\(marker.mediaID.uuidString)")
                }
            }
        }
    }
}

// MARK: - Gestures

private struct DiveDepthProfileOverlayChartInteractionModifier: ViewModifier {
    let allowsZoomAndPan: Bool
    let rect: CGRect
    let maxElapsed: Double
    let horizontalEdgeBufferFraction: CGFloat
    @Binding var chartViewport: DiveDepthProfileChartViewport?
    @Binding var panGestureLastTranslationX: CGFloat
    let depthSampleCount: Int
    let pendingFingerLocation: DiveDepthProfilePendingFingerLocation
    @Binding var scrubHoldTask: Task<Void, Never>?
    @Binding var scrubActive: Bool
    @Binding var scrubDepthIndex: Int?
    let scrubHoldDuration: Duration
    let nearestDepthIndex: (CGPoint) -> Int?
    let cancelScrubHoldTask: () -> Void
    let clearScrubState: () -> Void

    func body(content: Content) -> some View {
        if allowsZoomAndPan {
            content
                .simultaneousGesture(scrubGesture)
                .gesture(
                    DiveDepthProfileChartZoomPanGestures(
                        rect: rect,
                        maxElapsed: maxElapsed,
                        horizontalEdgeBufferFraction: horizontalEdgeBufferFraction,
                        chartViewport: $chartViewport,
                        panGestureLastTranslationX: $panGestureLastTranslationX
                    )
                )
                .onTapGesture(count: 2) {
                    chartViewport?.reset(fullElapsedMax: maxElapsed)
                }
        } else {
            content.gesture(scrubGesture)
        }
    }

    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard depthSampleCount >= 2 else { return }
                let loc = value.location
                // Class mutation — no view invalidation until scrub activates.
                pendingFingerLocation.point = loc

                if scrubHoldTask == nil {
                    scrubHoldTask = Task { @MainActor in
                        try? await Task.sleep(for: scrubHoldDuration)
                        guard !Task.isCancelled else { return }
                        guard let current = pendingFingerLocation.point else { return }
                        guard let index = nearestDepthIndex(current) else { return }
                        scrubActive = true
                        scrubDepthIndex = index
                    }
                } else if scrubActive {
                    if let index = nearestDepthIndex(loc) {
                        scrubDepthIndex = index
                    } else {
                        scrubActive = false
                        scrubDepthIndex = nil
                    }
                }
            }
            .onEnded { _ in
                cancelScrubHoldTask()
                clearScrubState()
            }
    }
}

#if canImport(UIKit)
import UIKit

/// UIKit pinch + two-finger pan on the chart view (iOS 18 **`UIGestureRecognizerRepresentable`**).
///
/// Uses **`.gesture(_:)`** (not **`simultaneousGesture`**) per Apple’s API; the coordinator installs
/// a companion pan recognizer on the same host view.
private struct DiveDepthProfileChartZoomPanGestures: UIGestureRecognizerRepresentable {
    var rect: CGRect
    var maxElapsed: Double
    var horizontalEdgeBufferFraction: CGFloat = 0
    @Binding var chartViewport: DiveDepthProfileChartViewport?
    @Binding var panGestureLastTranslationX: CGFloat

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(
            chartViewport: $chartViewport,
            panGestureLastTranslationX: $panGestureLastTranslationX
        )
    }

    func makeUIGestureRecognizer(context: Context) -> UIPinchGestureRecognizer {
        let pinch = UIPinchGestureRecognizer()
        pinch.delegate = context.coordinator
        pinch.cancelsTouchesInView = false
        return pinch
    }

    func updateUIGestureRecognizer(_ recognizer: UIPinchGestureRecognizer, context: Context) {
        context.coordinator.syncLayout(
            rect: rect,
            maxElapsed: maxElapsed,
            horizontalEdgeBufferFraction: horizontalEdgeBufferFraction
        )
        context.coordinator.ensurePanInstalled(on: recognizer.view)
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPinchGestureRecognizer, context: Context) {
        context.coordinator.syncLayout(
            rect: rect,
            maxElapsed: maxElapsed,
            horizontalEdgeBufferFraction: horizontalEdgeBufferFraction
        )
        context.coordinator.ensurePanInstalled(on: recognizer.view)

        switch recognizer.state {
        case .began:
            context.coordinator.pinchLastAppliedScale = 1
        case .changed:
            let scaleDelta = Double(recognizer.scale / max(context.coordinator.pinchLastAppliedScale, 0.001))
            guard scaleDelta > 0, var viewport = chartViewport else { return }
            viewport.zoom(
                scale: scaleDelta,
                anchorFraction: 0.5,
                fullElapsedMax: maxElapsed
            )
            chartViewport = viewport
            context.coordinator.pinchLastAppliedScale = recognizer.scale
        case .ended, .cancelled, .failed:
            context.coordinator.pinchLastAppliedScale = 1
            recognizer.scale = 1
        default:
            break
        }
    }

    func dismantleUIGestureRecognizer(_ recognizer: UIPinchGestureRecognizer, coordinator: Coordinator) {
        coordinator.detachPan()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        @Binding var chartViewport: DiveDepthProfileChartViewport?
        @Binding var panGestureLastTranslationX: CGFloat

        var rect: CGRect = .zero
        var maxElapsed: Double = 0
        var horizontalEdgeBufferFraction: CGFloat = 0
        var pinchLastAppliedScale: CGFloat = 1

        private weak var hostView: UIView?
        private var panRecognizer: UIPanGestureRecognizer?

        init(
            chartViewport: Binding<DiveDepthProfileChartViewport?>,
            panGestureLastTranslationX: Binding<CGFloat>
        ) {
            _chartViewport = chartViewport
            _panGestureLastTranslationX = panGestureLastTranslationX
        }

        func syncLayout(
            rect: CGRect,
            maxElapsed: Double,
            horizontalEdgeBufferFraction: CGFloat
        ) {
            self.rect = rect
            self.maxElapsed = maxElapsed
            self.horizontalEdgeBufferFraction = horizontalEdgeBufferFraction
        }

        func ensurePanInstalled(on view: UIView?) {
            guard let view else { return }
            guard hostView !== view || panRecognizer == nil else { return }
            detachPan()
            hostView = view
            view.isMultipleTouchEnabled = true

            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.minimumNumberOfTouches = 2
            pan.maximumNumberOfTouches = 2
            pan.delegate = self
            pan.cancelsTouchesInView = false
            view.addGestureRecognizer(pan)
            panRecognizer = pan
        }

        func detachPan() {
            if let panRecognizer, let hostView {
                hostView.removeGestureRecognizer(panRecognizer)
            }
            panRecognizer = nil
            hostView = nil
        }

        @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                panGestureLastTranslationX = 0
            case .changed:
                guard var viewport = chartViewport, canPan(viewport: viewport) else { return }

                let translationX = recognizer.translation(in: recognizer.view).x
                let deltaX = translationX - panGestureLastTranslationX
                panGestureLastTranslationX = translationX
                let dataWidth = DiveDepthProfileOverlayChartLayout.dataPlotRect(
                    in: rect,
                    horizontalEdgeBufferFraction: horizontalEdgeBufferFraction
                ).width
                let elapsedDelta = -Double(deltaX / max(dataWidth, 1)) * viewport.elapsedSpan
                viewport.pan(elapsedDelta: elapsedDelta, fullElapsedMax: maxElapsed)
                chartViewport = viewport
            case .ended, .cancelled, .failed:
                panGestureLastTranslationX = 0
            default:
                break
            }
        }

        private func canPan(viewport: DiveDepthProfileChartViewport) -> Bool {
            viewport.elapsedSpan < max(maxElapsed, 0.001) * 0.999
        }

        @objc func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer === panRecognizer else { return true }
            guard let viewport = chartViewport else { return false }
            return canPan(viewport: viewport)
        }

        @objc func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        deinit {
            detachPan()
        }
    }
}
#endif
