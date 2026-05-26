import SwiftUI

/// Compact depth profile with optional yellow gas line (**PSI** above ending pressure) and dual scrub callout.
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

            ZStack(alignment: .topLeading) {
                if depthSamples.count < 2 {
                    Text("Not enough points to draw a profile.")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.Colors.tabUnselected)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    Group {
                        if showsGasOverlay, let baseline, let maxAboveBaseline {
                            pressurePolyline(
                                in: rect,
                                viewport: viewport,
                                baselinePSI: baseline,
                                maxPressureAboveBaseline: maxAboveBaseline
                            )
                        }
                        depthPolyline(in: rect, viewport: viewport, maxDepth: maxDepth)
                        mediaMarkerLayer(in: rect, viewport: viewport, maxDepth: maxDepth)

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

                    if allowsZoomAndPan {
                        zoomInteractionHint(isZoomed: viewport.isZoomed(fullElapsedMax: maxElapsed))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(8)
                    }
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

    @ViewBuilder
    private func zoomInteractionHint(isZoomed: Bool) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("Pinch to zoom · 2 fingers to pan")
            if isZoomed {
                Text("Double-tap to reset")
            }
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(AppTheme.Colors.tabUnselected)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .accessibilityLabel(
            isZoomed
                ? "Pinch to zoom. Two fingers to pan. Double tap to reset zoom."
                : "Pinch to zoom. Two fingers to pan. Hold and drag with one finger to inspect depth and pressure."
        )
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

    private func depthPolyline(
        in rect: CGRect,
        viewport: DiveDepthProfileChartViewport,
        maxDepth: Double
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
        .stroke(AppTheme.Colors.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }

    private func mediaMarkerLayer(
        in rect: CGRect,
        viewport: DiveDepthProfileChartViewport,
        maxDepth: Double
    ) -> some View {
        ForEach(mediaMarkers) { marker in
            if viewport.contains(elapsedSeconds: marker.elapsedSeconds),
               let media = mediaPhotosByID[marker.mediaID] {
                Button {
                    onMediaMarkerTap?(marker)
                } label: {
                    DiveDepthProfileMediaMarkerView(media: media)
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

    private func pressurePolyline(
        in rect: CGRect,
        viewport: DiveDepthProfileChartViewport,
        baselinePSI: Double,
        maxPressureAboveBaseline: Double
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

    private func scrubCallout(depthMeters: Double, pressurePSI: Double?, anchor: CGPoint, in rect: CGRect) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Depth \(formattedDepth(depthMeters))")
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
        .position(scrubCalloutPosition(point: anchor, in: rect))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(scrubAccessibilityLabel(depthMeters: depthMeters, pressurePSI: pressurePSI))
    }

    private func scrubAccessibilityLabel(depthMeters: Double, pressurePSI: Double?) -> String {
        if let pressurePSI {
            return "Depth \(formattedDepth(depthMeters)), pressure \(formattedPressure(pressurePSI))"
        }
        return "Depth \(formattedDepth(depthMeters))"
    }

    private func scrubCalloutPosition(point: CGPoint, in rect: CGRect) -> CGPoint {
        let boxHalfW: CGFloat = 78
        let boxHalfH: CGFloat = 28
        let margin: CGFloat = 6
        let preferredY = point.y - 44
        let yTop = min(preferredY, point.y - margin - boxHalfH)
        let y = max(rect.minY + boxHalfH + margin, yTop)
        let x = min(max(point.x, rect.minX + boxHalfW + margin), rect.maxX - boxHalfW - margin)
        return CGPoint(x: x, y: y)
    }

    private func formattedDepth(_ meters: Double) -> String {
        DiveQuantityFormatting.depth(meters: meters, system: diveDisplayUnitSystem)
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
                .background {
                    DiveDepthProfileChartZoomPanInstaller(
                        rect: rect,
                        maxElapsed: maxElapsed,
                        chartViewport: $chartViewport,
                        panGestureLastTranslationX: $panGestureLastTranslationX
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                }
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

/// UIKit pinch + two-finger pan on the chart host (avoids SwiftUI magnification stealing parallel-finger drags).
private struct DiveDepthProfileChartZoomPanInstaller: UIViewRepresentable {
    let rect: CGRect
    let maxElapsed: Double
    @Binding var chartViewport: DiveDepthProfileChartViewport?
    @Binding var panGestureLastTranslationX: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(
            rect: rect,
            maxElapsed: maxElapsed,
            chartViewport: $chartViewport,
            panGestureLastTranslationX: $panGestureLastTranslationX
        )
    }

    func makeUIView(context: Context) -> AnchorView {
        let view = AnchorView()
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: AnchorView, context: Context) {
        uiView.coordinator = context.coordinator
        context.coordinator.rect = rect
        context.coordinator.maxElapsed = maxElapsed
        context.coordinator.attachIfNeeded(from: uiView)
    }

    final class AnchorView: UIView {
        var coordinator: Coordinator?

        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            coordinator?.attachIfNeeded(from: self)
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            coordinator?.attachIfNeeded(from: self)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var rect: CGRect
        var maxElapsed: Double
        @Binding var chartViewport: DiveDepthProfileChartViewport?
        @Binding var panGestureLastTranslationX: CGFloat

        private weak var hostView: UIView?
        private var panRecognizer: UIPanGestureRecognizer?
        private var pinchRecognizer: UIPinchGestureRecognizer?

        private var panActive = false
        private var pinchActive = false
        private var sessionPrefersPan = false
        private var pinchLastAppliedScale: CGFloat = 1

        init(
            rect: CGRect,
            maxElapsed: Double,
            chartViewport: Binding<DiveDepthProfileChartViewport?>,
            panGestureLastTranslationX: Binding<CGFloat>
        ) {
            self.rect = rect
            self.maxElapsed = maxElapsed
            _chartViewport = chartViewport
            _panGestureLastTranslationX = panGestureLastTranslationX
        }

        func attachIfNeeded(from anchor: UIView) {
            guard let host = anchor.superview else { return }
            guard hostView !== host else { return }
            detach()
            hostView = host
            host.isMultipleTouchEnabled = true

            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.minimumNumberOfTouches = 2
            pan.maximumNumberOfTouches = 2
            pan.delegate = self
            host.addGestureRecognizer(pan)
            panRecognizer = pan

            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            pinch.delegate = self
            host.addGestureRecognizer(pinch)
            pinchRecognizer = pinch
        }

        func detach() {
            if let panRecognizer, let hostView {
                hostView.removeGestureRecognizer(panRecognizer)
            }
            if let pinchRecognizer, let hostView {
                hostView.removeGestureRecognizer(pinchRecognizer)
            }
            panRecognizer = nil
            pinchRecognizer = nil
            hostView = nil
        }

        @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                panActive = true
                panGestureLastTranslationX = 0
            case .changed:
                guard var viewport = chartViewport, viewport.isZoomed(fullElapsedMax: maxElapsed) else { return }

                let translation = recognizer.translation(in: hostView)
                let cumulativeScaleChange = Double((pinchRecognizer?.scale ?? 1) - 1)
                let panIntent = DiveDepthProfileChartGesturePolicy.prefersPanOverPinch(
                    horizontalTranslation: translation.x,
                    verticalTranslation: translation.y,
                    cumulativeScaleChange: cumulativeScaleChange
                )
                if panIntent {
                    sessionPrefersPan = true
                }
                guard sessionPrefersPan else { return }

                let deltaX = translation.x - panGestureLastTranslationX
                panGestureLastTranslationX = translation.x
                let elapsedDelta = -Double(deltaX / max(rect.width, 1)) * viewport.elapsedSpan
                viewport.pan(elapsedDelta: elapsedDelta, fullElapsedMax: maxElapsed)
                chartViewport = viewport
            case .ended, .cancelled, .failed:
                panActive = false
                panGestureLastTranslationX = 0
                endSessionIfNeeded()
            default:
                break
            }
        }

        @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .began:
                pinchActive = true
                pinchLastAppliedScale = 1
            case .changed:
                guard !sessionPrefersPan else { return }

                let scaleDelta = Double(recognizer.scale / max(pinchLastAppliedScale, 0.001))
                guard scaleDelta > 0,
                      DiveDepthProfileChartGesturePolicy.shouldApplyPinchZoom(scaleDeltaSinceLastApply: scaleDelta)
                else { return }

                chartViewport?.zoom(
                    scale: scaleDelta,
                    anchorFraction: 0.5,
                    fullElapsedMax: maxElapsed
                )
                pinchLastAppliedScale = recognizer.scale
            case .ended, .cancelled, .failed:
                pinchActive = false
                pinchLastAppliedScale = 1
                recognizer.scale = 1
                endSessionIfNeeded()
            default:
                break
            }
        }

        private func endSessionIfNeeded() {
            guard !panActive, !pinchActive else { return }
            sessionPrefersPan = false
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            guard let panRecognizer, let pinchRecognizer else { return false }
            let pair = Set([gestureRecognizer, otherGestureRecognizer])
            return pair == Set([panRecognizer, pinchRecognizer])
        }

        deinit {
            detach()
        }
    }
}
#endif
