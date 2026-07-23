import SwiftUI

/// Heart rate vs elapsed time — polyline with touch-and-hold scrub.
struct SnorkelHeartRateProfileChart: View {
    let samples: [SnorkelHeartRateProfileSample]
    var sessionMaxBPMHint: Int?

    private static let scrubHoldDuration: Duration = .milliseconds(180)

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
            let maxBPM = chartMaxBPM

            ZStack(alignment: .topLeading) {
                if samples.count < 2 {
                    Text("No heart rate samples.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.tabUnselected)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .accessibilityIdentifier("SnorkelHeartRateProfileChart.NoSamples")
                } else {
                    heartRatePolyline(in: rect, maxElapsed: maxElapsed, maxBPM: maxBPM)

                    if scrubActive, let idx = scrubSampleIndex, samples.indices.contains(idx) {
                        scrubChrome(in: rect, maxElapsed: maxElapsed, maxBPM: maxBPM, sampleIndex: idx)
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

    private var chartMaxBPM: Double {
        let dataMax = Double(samples.map(\.heartRateBPM).max() ?? 0)
        let hint = Double(sessionMaxBPMHint ?? 0)
        return max(dataMax, hint, 120)
    }

    private func heartRatePolyline(in rect: CGRect, maxElapsed: Double, maxBPM: Double) -> some View {
        Path { path in
            for (i, sample) in samples.enumerated() {
                let p = plotPoint(sample: sample, in: rect, maxElapsed: maxElapsed, maxBPM: maxBPM)
                if i == 0 {
                    path.move(to: p)
                } else {
                    path.addLine(to: p)
                }
            }
        }
        .stroke(Color.red, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }

    @ViewBuilder
    private func scrubChrome(
        in rect: CGRect,
        maxElapsed: Double,
        maxBPM: Double,
        sampleIndex idx: Int
    ) -> some View {
        let sample = samples[idx]
        let p = plotPoint(sample: sample, in: rect, maxElapsed: maxElapsed, maxBPM: maxBPM)

        Path { path in
            path.move(to: CGPoint(x: p.x, y: rect.minY))
            path.addLine(to: CGPoint(x: p.x, y: rect.maxY))
        }
        .stroke(Color.red.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

        Circle()
            .fill(Color.red)
            .frame(width: 10, height: 10)
            .overlay {
                Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5)
            }
            .position(p)

        Text("\(sample.heartRateBPM) bpm")
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
            .position(x: min(max(p.x, rect.minX + 40), rect.maxX - 40), y: rect.minY + 14)
    }

    private func plotPoint(
        sample: SnorkelHeartRateProfileSample,
        in rect: CGRect,
        maxElapsed: Double,
        maxBPM: Double
    ) -> CGPoint {
        let xFrac = sample.elapsedSeconds / maxElapsed
        let yFrac = Double(sample.heartRateBPM) / maxBPM
        return CGPoint(
            x: rect.minX + CGFloat(xFrac) * rect.width,
            y: rect.maxY - CGFloat(yFrac) * rect.height
        )
    }

    private func chartScrubGesture(rect: CGRect, maxElapsed: Double) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let location = value.location
                guard rect.contains(location) else { return }
                if !scrubActive {
                    cancelScrubHoldTask()
                    scrubHoldTask = Task {
                        try? await Task.sleep(for: Self.scrubHoldDuration)
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            scrubActive = true
                            updateScrubIndex(at: location, in: rect, maxElapsed: maxElapsed)
                        }
                    }
                } else {
                    updateScrubIndex(at: location, in: rect, maxElapsed: maxElapsed)
                }
            }
            .onEnded { _ in
                cancelScrubHoldTask()
                clearScrubState()
            }
    }

    private func updateScrubIndex(at location: CGPoint, in rect: CGRect, maxElapsed: Double) {
        let xFrac = (location.x - rect.minX) / max(rect.width, 1)
        let targetElapsed = Double(xFrac) * maxElapsed
        var bestIndex = 0
        var bestDelta = TimeInterval.greatestFiniteMagnitude
        for (i, sample) in samples.enumerated() {
            let delta = abs(sample.elapsedSeconds - targetElapsed)
            if delta < bestDelta {
                bestDelta = delta
                bestIndex = i
            }
        }
        scrubSampleIndex = bestIndex
    }

    private func cancelScrubHoldTask() {
        scrubHoldTask?.cancel()
        scrubHoldTask = nil
    }

    private func clearScrubState() {
        scrubActive = false
        scrubSampleIndex = nil
    }
}
