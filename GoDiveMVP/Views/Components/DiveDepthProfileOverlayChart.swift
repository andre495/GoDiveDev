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
    /// Landscape minimized profile with media markers — pinch to zoom; two-finger pan; one-finger scrub.
    var allowsZoomAndPan = false
    var onMediaMarkerTap: ((DiveDepthProfileMediaMarker) -> Void)? = nil

    private static let scrubHoldDuration: Duration = .milliseconds(180)
    @State private var fingerLocationInChart: CGPoint?
    @State private var scrubHoldTask: Task<Void, Never>?
    @State private var scrubActive = false
    @State private var scrubDepthIndex: Int?
    @State private var chartViewport: DiveDepthProfileChartViewport?
    @State private var panGestureLastTranslationX: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let rect = DiveDepthProfileOverlayChartLayout.plotRect(in: geo.size)
            let maxElapsed = chartMaxElapsed
            let maxDepth = chartMaxDepth
            let viewport = activeViewport(fullElapsedMax: maxElapsed)
            let baseline = resolvedBaselinePSI
            let maxAboveBaseline = baseline.map {
                DiveDepthProfileOverlayChartLayout.maxPressureAboveBaseline(
                    pressureSamples: pressureSamples,
                    baselinePSI: $0
                )
            }
            let lineReveal = min(1, max(0, profileLineRevealProgress))

            ZStack(alignment: .topLeading) {
                if depthSamples.count < 2 {
                    Text("Not enough points to draw a profile.")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.Colors.tabUnselected)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    axisChrome(in: rect, viewport: viewport, maxDepth: maxDepth)

                    Group {
                        Group {
                            if showsGasOverlay, let baseline, let maxAboveBaseline {
                                pressurePolyline(
                                    in: rect,
                                    viewport: viewport,
                                    baselinePSI: baseline,
                                    maxPressureAboveBaseline: maxAboveBaseline,
                                    revealProgress: lineReveal
                                )
                            }
                            depthPolyline(
                                in: rect,
                                viewport: viewport,
                                maxDepth: maxDepth,
                                revealProgress: lineReveal
                            )
                        }
                        .drawingGroup()

                        mediaMarkerLayer(
                            in: rect,
                            viewport: viewport,
                            maxDepth: maxDepth,
                            fullElapsedMax: maxElapsed
                        )
                        .opacity(Double(lineReveal))

                        if scrubActive, let idx = scrubDepthIndex, depthSamples.indices.contains(idx) {
                            scrubChrome(
                                in: rect,
                                viewport: viewport,
                                maxDepth: maxDepth,
                                depthIndex: idx,
                                baselinePSI: baseline,
                                maxPressureAboveBaseline: maxAboveBaseline
                            )
                        }
                    }
                    .clipShape(Rectangle())
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .modifier(
                DiveDepthProfileOverlayChartInteractionModifier(
                    allowsZoomAndPan: allowsZoomAndPan,
                    rect: rect,
                    maxElapsed: maxElapsed,
                    chartViewport: $chartViewport,
                    panGestureLastTranslationX: $panGestureLastTranslationX,
                    depthSampleCount: depthSamples.count,
                    fingerLocationInChart: $fingerLocationInChart,
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
        pressureSamples.count >= 2 && resolvedBaselinePSI != nil
    }

    private var resolvedBaselinePSI: Double? {
        DiveDepthProfileOverlayChartLayout.resolvedPressureBaselinePSI(
            endingPSI: pressureBaselinePSI,
            pressureSamples: pressureSamples
        )
    }

    private var chartMaxElapsed: Double {
        let depthMax = depthSamples.map(\.elapsedSeconds).max() ?? 0
        let pressureMax = pressureSamples.map(\.elapsedSeconds).max() ?? 0
        return max(depthMax, pressureMax, 0.001)
    }

    private var chartMaxDepth: Double {
        let maxDepthData = depthSamples.map(\.depthMeters).max() ?? 0
        return max(maxDepthData, maxDepthHintMeters, 0.5)
    }

    private func axisChrome(
        in rect: CGRect,
        viewport: DiveDepthProfileChartViewport,
        maxDepth: Double
    ) -> some View {
        let timeTicks = DiveDepthProfileChartAxisPresentation.timeTicks(viewport: viewport)
        let depthTicks = DiveDepthProfileChartAxisPresentation.depthTicks(
            maxDepthMeters: maxDepth,
            system: diveDisplayUnitSystem
        )
        let axisColor = AppTheme.Colors.tabUnselected.opacity(0.55)
        let tickLength: CGFloat = 4

        return ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            }
            .stroke(axisColor, style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))

            ForEach(Array(depthTicks.enumerated()), id: \.offset) { _, tick in
                let point = DiveDepthProfileChartAxisPresentation.depthTickPoint(
                    fraction: tick.fraction,
                    in: rect
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

    private func depthPolyline(
        in rect: CGRect,
        viewport: DiveDepthProfileChartViewport,
        maxDepth: Double,
        revealProgress: CGFloat
    ) -> some View {
        Path { path in
            for (i, sample) in depthSamples.enumerated() {
                let p = DiveDepthProfileOverlayChartLayout.depthPoint(
                    sample: sample,
                    in: rect,
                    viewport: viewport,
                    maxDepth: maxDepth
                )
                if i == 0 {
                    path.move(to: p)
                } else {
                    path.addLine(to: p)
                }
            }
        }
        .trim(from: 0, to: revealProgress)
        .stroke(AppTheme.Colors.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }

    private func mediaMarkerLayer(
        in rect: CGRect,
        viewport: DiveDepthProfileChartViewport,
        maxDepth: Double,
        fullElapsedMax: Double
    ) -> some View {
        let markerThumbnailSize = DiveDepthProfileMediaPlotting.markerThumbnailDisplaySize(
            viewport: viewport,
            fullElapsedMax: fullElapsedMax
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
                            maxDepth: maxDepth
                        )
                    )
                    .accessibilityIdentifier("DiveDepthProfileOverlayChart.MediaMarker.\(marker.mediaID.uuidString)")
                }
            }
        }
    }

    private func pressurePolyline(
        in rect: CGRect,
        viewport: DiveDepthProfileChartViewport,
        baselinePSI: Double,
        maxPressureAboveBaseline: Double,
        revealProgress: CGFloat
    ) -> some View {
        Path { path in
            for (i, sample) in pressureSamples.enumerated() {
                let p = DiveDepthProfileOverlayChartLayout.pressurePoint(
                    sample: sample,
                    in: rect,
                    viewport: viewport,
                    baselinePSI: baselinePSI,
                    maxPressureAboveBaseline: maxPressureAboveBaseline
                )
                if i == 0 {
                    path.move(to: p)
                } else {
                    path.addLine(to: p)
                }
            }
        }
        .trim(from: 0, to: revealProgress)
        .stroke(AppTheme.Colors.tankGasAccent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }

    @ViewBuilder
    private func scrubChrome(
        in rect: CGRect,
        viewport: DiveDepthProfileChartViewport,
        maxDepth: Double,
        depthIndex idx: Int,
        baselinePSI: Double?,
        maxPressureAboveBaseline: Double?
    ) -> some View {
        let depthSample = depthSamples[idx]
        let depthPoint = DiveDepthProfileOverlayChartLayout.depthPoint(
            sample: depthSample,
            in: rect,
            viewport: viewport,
            maxDepth: maxDepth
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

        if let baselinePSI,
           let maxPressureAboveBaseline,
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
                baselinePSI: baselinePSI,
                maxPressureAboveBaseline: maxPressureAboveBaseline
            )

            Circle()
                .fill(AppTheme.Colors.tankGasAccent)
                .frame(width: 10, height: 10)
                .overlay {
                    Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                }
                .position(gasPoint)
        }

        scrubCallout(
            elapsedSeconds: depthSample.elapsedSeconds,
            depthMeters: depthSample.depthMeters,
            pressurePSI: scrubPressurePSI(for: depthSample),
            anchor: depthPoint,
            in: rect
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
        VStack(alignment: .leading, spacing: 2) {
            Text(DiveDepthProfileChartAxisPresentation.scrubTimeLabel(elapsedSeconds: elapsedSeconds))
            Text(DiveDepthProfileChartAxisPresentation.scrubDepthLabel(
                depthMeters: depthMeters,
                system: diveDisplayUnitSystem
            ))
            if let pressurePSI {
                Text("Pressure \(formattedPressure(pressurePSI))")
                    .foregroundStyle(AppTheme.Colors.tankGasAccent)
            }
        }
        .font(.caption.weight(.semibold).monospacedDigit())
        .foregroundStyle(AppTheme.Colors.textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.Colors.tabUnselected.opacity(0.25), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
        .position(scrubCalloutPosition(point: anchor, pressurePresent: pressurePSI != nil, in: rect))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            scrubAccessibilityLabel(
                elapsedSeconds: elapsedSeconds,
                depthMeters: depthMeters,
                pressurePSI: pressurePSI
            )
        )
    }

    private func scrubAccessibilityLabel(
        elapsedSeconds: Double,
        depthMeters: Double,
        pressurePSI: Double?
    ) -> String {
        var parts = [
            DiveDepthProfileChartAxisPresentation.scrubTimeLabel(elapsedSeconds: elapsedSeconds),
            DiveDepthProfileChartAxisPresentation.scrubDepthLabel(
                depthMeters: depthMeters,
                system: diveDisplayUnitSystem
            ),
        ]
        if let pressurePSI {
            parts.append("Pressure \(formattedPressure(pressurePSI))")
        }
        return parts.joined(separator: ", ")
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

    private func formattedPressure(_ psi: Double) -> String {
        DiveQuantityFormatting.cylinderPressure(fromPSI: psi, system: diveDisplayUnitSystem)
    }

    private func nearestDepthIndex(
        location: CGPoint,
        rect: CGRect,
        viewport: DiveDepthProfileChartViewport
    ) -> Int {
        let target = DiveDepthProfileOverlayChartLayout.elapsedSeconds(
            atChartX: location.x,
            rectMinX: rect.minX,
            rectWidth: rect.width,
            viewport: viewport
        )
        return DiveDepthProfileSeries.indexNearestElapsed(target, in: depthSamples)
    }

    private func cancelScrubHoldTask() {
        scrubHoldTask?.cancel()
        scrubHoldTask = nil
    }

    private func clearScrubState() {
        fingerLocationInChart = nil
        scrubActive = false
        scrubDepthIndex = nil
    }
}

// MARK: - Gestures

private struct DiveDepthProfileOverlayChartInteractionModifier: ViewModifier {
    let allowsZoomAndPan: Bool
    let rect: CGRect
    let maxElapsed: Double
    @Binding var chartViewport: DiveDepthProfileChartViewport?
    @Binding var panGestureLastTranslationX: CGFloat
    let depthSampleCount: Int
    @Binding var fingerLocationInChart: CGPoint?
    @Binding var scrubHoldTask: Task<Void, Never>?
    @Binding var scrubActive: Bool
    @Binding var scrubDepthIndex: Int?
    let scrubHoldDuration: Duration
    let nearestDepthIndex: (CGPoint) -> Int
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
                fingerLocationInChart = loc

                if scrubHoldTask == nil {
                    scrubHoldTask = Task { @MainActor in
                        try? await Task.sleep(for: scrubHoldDuration)
                        guard !Task.isCancelled else { return }
                        guard let current = fingerLocationInChart else { return }
                        scrubActive = true
                        scrubDepthIndex = nearestDepthIndex(current)
                    }
                } else if scrubActive {
                    scrubDepthIndex = nearestDepthIndex(loc)
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
        context.coordinator.syncLayout(rect: rect, maxElapsed: maxElapsed)
        context.coordinator.ensurePanInstalled(on: recognizer.view)
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPinchGestureRecognizer, context: Context) {
        context.coordinator.syncLayout(rect: rect, maxElapsed: maxElapsed)
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

        func syncLayout(rect: CGRect, maxElapsed: Double) {
            self.rect = rect
            self.maxElapsed = maxElapsed
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
                let elapsedDelta = -Double(deltaX / max(rect.width, 1)) * viewport.elapsedSpan
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
