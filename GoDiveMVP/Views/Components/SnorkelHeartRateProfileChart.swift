import SwiftUI

/// Heart rate vs elapsed time — edge-to-edge under-curve deep-water fill, polyline, and
/// touch-and-hold scrub (**Time … min** + **Heart Rate … bpm**), styled like the dive depth profile chart.
struct SnorkelHeartRateProfileChart: View {
    let samples: [SnorkelHeartRateProfileSample]
    var sessionMaxBPMHint: Int?
    /// Soft top fade so the plot dissolves under tab chrome (tank depth parity).
    var topEdgeFadeFraction: CGFloat = 0
    /// When **true**, the parent owns the callout via **`onScrubCalloutChange`**.
    var pinsScrubCalloutUnderTabMenu: Bool = false
    var onScrubCalloutChange: ((SnorkelHeartRateScrubCallout?) -> Void)? = nil

    private static let scrubHoldDuration: Duration = .milliseconds(180)

    /// Pending finger during hold — class mutation avoids SwiftUI body invalidation before scrub activates.
    @State private var pendingFingerLocation = SnorkelHeartRatePendingFingerLocation()
    @State private var scrubHoldTask: Task<Void, Never>?
    @State private var scrubActive = false
    @State private var scrubSampleIndex: Int?

    var body: some View {
        GeometryReader { geo in
            // Edge-to-edge plot (same as depth chart **`.edgeToEdge`** chrome).
            let rect = CGRect(origin: .zero, size: geo.size)
            let maxElapsed = SnorkelHeartRateProfileChartPresentation.chartMaxElapsed(samples: samples)
            let maxBPM = SnorkelHeartRateProfileChartPresentation.chartMaxBPM(
                samples: samples,
                sessionMaxBPMHint: sessionMaxBPMHint
            )

            ZStack(alignment: .topLeading) {
                if samples.count < 2 {
                    Text("No heart rate samples.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.tabUnselected)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .accessibilityIdentifier("SnorkelHeartRateProfileChart.NoSamples")
                } else {
                    underCurveFill(in: rect, maxElapsed: maxElapsed, maxBPM: maxBPM)
                    heartRatePolyline(in: rect, maxElapsed: maxElapsed, maxBPM: maxBPM)

                    if scrubActive, let idx = scrubSampleIndex, samples.indices.contains(idx) {
                        scrubChrome(in: rect, maxElapsed: maxElapsed, maxBPM: maxBPM, sampleIndex: idx)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .mask {
                chartTopFadeMask(size: geo.size)
            }
            .contentShape(Rectangle())
            .gesture(chartScrubGesture(rect: rect, maxElapsed: maxElapsed))
            .onChange(of: scrubActive) { _, _ in
                publishScrubCallout()
            }
            .onChange(of: scrubSampleIndex) { _, _ in
                publishScrubCallout()
            }
            .onDisappear {
                cancelScrubHoldTask()
                clearScrubState()
            }
        }
    }

    private func underCurveFill(in rect: CGRect, maxElapsed: Double, maxBPM: Double) -> some View {
        let areaPath = SnorkelHeartRateProfileChartPresentation.underCurveAreaPath(
            samples: samples,
            in: rect,
            maxElapsed: maxElapsed,
            maxBPM: maxBPM
        )
        return DiveDepthProfileChartStaticUnderfillView(
            areaPath: areaPath,
            plotSize: rect.size
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func heartRatePolyline(in rect: CGRect, maxElapsed: Double, maxBPM: Double) -> some View {
        Path { path in
            for (i, sample) in samples.enumerated() {
                let p = SnorkelHeartRateProfileChartPresentation.plotPoint(
                    sample: sample,
                    in: rect,
                    maxElapsed: maxElapsed,
                    maxBPM: maxBPM
                )
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
        let p = SnorkelHeartRateProfileChartPresentation.plotPoint(
            sample: sample,
            in: rect,
            maxElapsed: maxElapsed,
            maxBPM: maxBPM
        )

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

        if !pinsScrubCalloutUnderTabMenu {
            scrubCalloutLabel(for: sample)
                .position(
                    SnorkelHeartRateProfileChartPresentation.scrubCalloutPosition(point: p, in: rect)
                )
        }
    }

    private func scrubCalloutLabel(for sample: SnorkelHeartRateProfileSample) -> some View {
        SnorkelHeartRateScrubCalloutLabel(
            callout: SnorkelHeartRateScrubCallout(
                elapsedSeconds: sample.elapsedSeconds,
                heartRateBPM: sample.heartRateBPM
            )
        )
    }

    @ViewBuilder
    private func chartTopFadeMask(size: CGSize) -> some View {
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

    private func chartScrubGesture(rect: CGRect, maxElapsed: Double) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard samples.count >= 2 else { return }
                let location = value.location
                // Class mutation — no view invalidation until scrub activates.
                pendingFingerLocation.point = location

                if scrubHoldTask == nil {
                    scrubHoldTask = Task { @MainActor in
                        try? await Task.sleep(for: Self.scrubHoldDuration)
                        guard !Task.isCancelled else { return }
                        guard let current = pendingFingerLocation.point else { return }
                        scrubActive = true
                        updateScrubIndex(at: current, in: rect, maxElapsed: maxElapsed)
                    }
                } else if scrubActive {
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
        let clamped = min(max(xFrac, 0), 1)
        let targetElapsed = Double(clamped) * maxElapsed
        scrubSampleIndex = SnorkelHeartRateProfileChartPresentation.indexNearestElapsed(
            samples: samples,
            targetElapsed: targetElapsed
        )
    }

    private func publishScrubCallout() {
        guard pinsScrubCalloutUnderTabMenu else { return }
        guard let onScrubCalloutChange else { return }
        guard scrubActive,
              let idx = scrubSampleIndex,
              samples.indices.contains(idx) else {
            onScrubCalloutChange(nil)
            return
        }
        let sample = samples[idx]
        onScrubCalloutChange(
            SnorkelHeartRateScrubCallout(
                elapsedSeconds: sample.elapsedSeconds,
                heartRateBPM: sample.heartRateBPM
            )
        )
    }

    private func cancelScrubHoldTask() {
        scrubHoldTask?.cancel()
        scrubHoldTask = nil
    }

    private func clearScrubState() {
        pendingFingerLocation.point = nil
        scrubActive = false
        scrubSampleIndex = nil
        if pinsScrubCalloutUnderTabMenu {
            onScrubCalloutChange?(nil)
        }
    }
}

/// Shared callout chrome for heart-rate scrub (time + BPM).
struct SnorkelHeartRateScrubCalloutLabel: View {
    let callout: SnorkelHeartRateScrubCallout

    var body: some View {
        let timeLabel = SnorkelHeartRateProfileChartPresentation.scrubTimeLabel(
            elapsedSeconds: callout.elapsedSeconds
        )
        let heartRateLabel = SnorkelHeartRateProfileChartPresentation.scrubHeartRateLabel(
            bpm: callout.heartRateBPM
        )

        VStack(alignment: .center, spacing: 2) {
            Text(timeLabel)
            Text(heartRateLabel)
        }
        .font(.caption.weight(.semibold).monospacedDigit())
        .foregroundStyle(AppTheme.Colors.textPrimary)
        .multilineTextAlignment(.center)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(timeLabel), \(heartRateLabel)")
    }
}

/// Class-backed finger location so hold-to-scrub can track movement without restarting the timer.
private final class SnorkelHeartRatePendingFingerLocation {
    var point: CGPoint?
}
