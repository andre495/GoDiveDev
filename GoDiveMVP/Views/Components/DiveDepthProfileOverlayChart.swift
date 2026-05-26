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
    var onMediaMarkerTap: ((DiveDepthProfileMediaMarker) -> Void)? = nil

    private static let scrubHoldDuration: Duration = .milliseconds(180)
    @State private var fingerLocationInChart: CGPoint?
    @State private var scrubHoldTask: Task<Void, Never>?
    @State private var scrubActive = false
    @State private var scrubDepthIndex: Int?

    var body: some View {
        GeometryReader { geo in
            let rect = DiveDepthProfileOverlayChartLayout.plotRect(in: geo.size)
            let maxElapsed = chartMaxElapsed
            let maxDepth = chartMaxDepth
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
                    if showsGasOverlay, let baseline, let maxAboveBaseline {
                        pressurePolyline(
                            in: rect,
                            maxElapsed: maxElapsed,
                            baselinePSI: baseline,
                            maxPressureAboveBaseline: maxAboveBaseline
                        )
                    }
                    depthPolyline(in: rect, maxElapsed: maxElapsed, maxDepth: maxDepth)
                    mediaMarkerLayer(in: rect, maxElapsed: maxElapsed, maxDepth: maxDepth)

                    if scrubActive, let idx = scrubDepthIndex, depthSamples.indices.contains(idx) {
                        scrubChrome(
                            in: rect,
                            maxElapsed: maxElapsed,
                            maxDepth: maxDepth,
                            depthIndex: idx,
                            baselinePSI: baseline,
                            maxPressureAboveBaseline: maxAboveBaseline
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(chartScrubGesture(rect: rect, maxElapsed: maxElapsed))
            .onDisappear {
                cancelScrubHoldTask()
                clearScrubState()
            }
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

    private func depthPolyline(in rect: CGRect, maxElapsed: Double, maxDepth: Double) -> some View {
        Path { path in
            for (i, sample) in depthSamples.enumerated() {
                let p = DiveDepthProfileOverlayChartLayout.depthPoint(
                    sample: sample,
                    in: rect,
                    maxElapsed: maxElapsed,
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

    private func mediaMarkerLayer(in rect: CGRect, maxElapsed: Double, maxDepth: Double) -> some View {
        ForEach(mediaMarkers) { marker in
            if let media = mediaPhotosByID[marker.mediaID] {
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
                        maxElapsed: maxElapsed,
                        maxDepth: maxDepth
                    )
                )
                .accessibilityIdentifier("DiveDepthProfileOverlayChart.MediaMarker.\(marker.mediaID.uuidString)")
            }
        }
    }

    private func pressurePolyline(
        in rect: CGRect,
        maxElapsed: Double,
        baselinePSI: Double,
        maxPressureAboveBaseline: Double
    ) -> some View {
        Path { path in
            for (i, sample) in pressureSamples.enumerated() {
                let p = DiveDepthProfileOverlayChartLayout.pressurePoint(
                    sample: sample,
                    in: rect,
                    maxElapsed: maxElapsed,
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
        maxElapsed: Double,
        maxDepth: Double,
        depthIndex idx: Int,
        baselinePSI: Double?,
        maxPressureAboveBaseline: Double?
    ) -> some View {
        let depthSample = depthSamples[idx]
        let depthPoint = DiveDepthProfileOverlayChartLayout.depthPoint(
            sample: depthSample,
            in: rect,
            maxElapsed: maxElapsed,
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
                maxElapsed: maxElapsed,
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

    private func nearestDepthIndex(location: CGPoint, rect: CGRect, maxElapsed: Double) -> Int {
        let target = DiveDepthProfileSeries.elapsedSeconds(
            atChartX: location.x,
            rectMinX: rect.minX,
            rectWidth: rect.width,
            maxElapsed: maxElapsed
        )
        return DiveDepthProfileSeries.indexNearestElapsed(target, in: depthSamples)
    }

    private func chartScrubGesture(rect: CGRect, maxElapsed: Double) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard depthSamples.count >= 2 else { return }
                let loc = value.location
                fingerLocationInChart = loc

                if scrubHoldTask == nil {
                    scrubHoldTask = Task { @MainActor in
                        try? await Task.sleep(for: Self.scrubHoldDuration)
                        guard !Task.isCancelled else { return }
                        guard let current = fingerLocationInChart else { return }
                        scrubActive = true
                        scrubDepthIndex = nearestDepthIndex(location: current, rect: rect, maxElapsed: maxElapsed)
                    }
                } else if scrubActive {
                    scrubDepthIndex = nearestDepthIndex(location: loc, rect: rect, maxElapsed: maxElapsed)
                }
            }
            .onEnded { _ in
                cancelScrubHoldTask()
                clearScrubState()
            }
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
