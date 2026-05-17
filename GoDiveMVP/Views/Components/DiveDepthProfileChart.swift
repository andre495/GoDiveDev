import SwiftUI

/// Depth vs elapsed time from first sample — polyline with touch-and-hold scrub (nearest sample depth).
/// Depths in **`DiveDepthProfileSample`** are stored in **meters**; labels follow **`EnvironmentValues.diveDisplayUnitSystem`**.
struct DiveDepthProfileChart: View {
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem

    let samples: [DiveDepthProfileSample]
    /// Used when samples are empty or max depth in samples is 0.
    var maxDepthHintMeters: Double
    /// `nil` when scrub ends or was never active; latest sample while scrubbing.
    var onScrubSampleChange: ((DiveDepthProfileSample?) -> Void)? = nil

    /// Hold this long (finger down) before the depth callout appears; then drag updates the nearest point.
    private static let scrubHoldDuration: Duration = .milliseconds(180)

    @State private var fingerLocationInChart: CGPoint?
    @State private var scrubHoldTask: Task<Void, Never>?
    @State private var scrubActive = false
    @State private var scrubSampleIndex: Int?

    var body: some View {
        GeometryReader { geo in
            let left: CGFloat = 4
            let top: CGFloat = 8
            let right: CGFloat = 4
            let bottom: CGFloat = 8
            let rect = CGRect(
                x: left,
                y: top,
                width: max(geo.size.width - left - right, 1),
                height: max(geo.size.height - top - bottom, 1)
            )
            let maxElapsed = chartMaxElapsed
            let maxDepth = chartMaxDepth

            ZStack(alignment: .topLeading) {
                if samples.count < 2 {
                    Text("Not enough points to draw a profile.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.tabUnselected)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    depthPolyline(in: rect, maxElapsed: maxElapsed, maxDepth: maxDepth)

                    if scrubActive, let idx = scrubSampleIndex, samples.indices.contains(idx) {
                        scrubChrome(in: rect, maxElapsed: maxElapsed, maxDepth: maxDepth, sampleIndex: idx)
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

    private var chartMaxElapsed: Double {
        max(samples.map(\.elapsedSeconds).max() ?? 0, 0.001)
    }

    private var chartMaxDepth: Double {
        let maxDepthData = samples.map(\.depthMeters).max() ?? 0
        return max(maxDepthData, maxDepthHintMeters, 0.5)
    }

    private func depthPolyline(in rect: CGRect, maxElapsed: Double, maxDepth: Double) -> some View {
        Path { path in
            for (i, s) in samples.enumerated() {
                let p = plotPoint(sample: s, in: rect, maxElapsed: maxElapsed, maxDepth: maxDepth)
                if i == 0 {
                    path.move(to: p)
                } else {
                    path.addLine(to: p)
                }
            }
        }
        .stroke(AppTheme.Colors.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }

    @ViewBuilder
    private func scrubChrome(in rect: CGRect, maxElapsed: Double, maxDepth: Double, sampleIndex idx: Int) -> some View {
        let sample = samples[idx]
        let p = plotPoint(sample: sample, in: rect, maxElapsed: maxElapsed, maxDepth: maxDepth)

        Path { path in
            path.move(to: CGPoint(x: p.x, y: rect.minY))
            path.addLine(to: CGPoint(x: p.x, y: rect.maxY))
        }
        .stroke(AppTheme.Colors.accent.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

        Circle()
            .fill(AppTheme.Colors.accent)
            .frame(width: 10, height: 10)
            .overlay {
                Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5)
            }
            .position(p)

        Text(formattedDepth(sample.depthMeters))
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
            .position(scrubCalloutPosition(point: p, in: rect))
            .accessibilityLabel("Scrubbed depth")
            .accessibilityValue(formattedDepth(sample.depthMeters))
    }

    /// Keeps the callout inside the chart rect horizontally; sits above the sample when there is room.
    private func scrubCalloutPosition(point: CGPoint, in rect: CGRect) -> CGPoint {
        let boxHalfW: CGFloat = 52
        let boxHalfH: CGFloat = 18
        let margin: CGFloat = 6
        let preferredY = point.y - 36
        let yTop = min(preferredY, point.y - margin - boxHalfH)
        let y = max(rect.minY + boxHalfH + margin, yTop)
        let x = min(max(point.x, rect.minX + boxHalfW + margin), rect.maxX - boxHalfW - margin)
        return CGPoint(x: x, y: y)
    }

    private func plotPoint(sample: DiveDepthProfileSample, in rect: CGRect, maxElapsed: Double, maxDepth: Double) -> CGPoint {
        let x = rect.minX + CGFloat(sample.elapsedSeconds / maxElapsed) * rect.width
        let y = rect.minY + CGFloat(sample.depthMeters / maxDepth) * rect.height
        return CGPoint(x: x, y: y)
    }

    private func formattedDepth(_ meters: Double) -> String {
        DiveQuantityFormatting.depth(meters: meters, system: diveDisplayUnitSystem)
    }

    private func nearestSampleIndex(location: CGPoint, rect: CGRect, maxElapsed: Double) -> Int {
        let target = DiveDepthProfileSeries.elapsedSeconds(
            atChartX: location.x,
            rectMinX: rect.minX,
            rectWidth: rect.width,
            maxElapsed: maxElapsed
        )
        return DiveDepthProfileSeries.indexNearestElapsed(target, in: samples)
    }

    private func chartScrubGesture(rect: CGRect, maxElapsed: Double) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard samples.count >= 2 else { return }
                let loc = value.location
                fingerLocationInChart = loc

                if scrubHoldTask == nil {
                    scrubHoldTask = Task { @MainActor in
                        try? await Task.sleep(for: Self.scrubHoldDuration)
                        guard !Task.isCancelled else { return }
                        guard let current = fingerLocationInChart else { return }
                        scrubActive = true
                        scrubSampleIndex = nearestSampleIndex(location: current, rect: rect, maxElapsed: maxElapsed)
                        notifyScrubSampleIfNeeded()
                    }
                } else if scrubActive {
                    scrubSampleIndex = nearestSampleIndex(location: loc, rect: rect, maxElapsed: maxElapsed)
                    notifyScrubSampleIfNeeded()
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
        scrubSampleIndex = nil
        onScrubSampleChange?(nil)
    }

    private func notifyScrubSampleIfNeeded() {
        guard let onScrubSampleChange else { return }
        guard scrubActive, let idx = scrubSampleIndex, samples.indices.contains(idx) else { return }
        onScrubSampleChange(samples[idx])
    }
}
