import SwiftUI
import UIKit

// MARK: - Legacy-aligned bubble math (testable; mirrors GoDive `BubbleData` / `AnimatedBackground` fills)

/// Values derived from `BrandAnimations.swift` (`AnimatedBackground` / `BubbleData`): radial two-stop fill, size and opacity ranges, rising scale toward **1.2**.
enum WaterBubbleRendering {
    static let paletteCount = 3

    /// Inner gradient stop opacity in **0.1...0.3**; outer stop is **inner × 0.3** (legacy radial edge).
    static func bubbleOpacities(hash: CGFloat) -> (inner: CGFloat, outer: CGFloat) {
        let inner = 0.1 + 0.2 * hash
        let outer = inner * 0.3
        return (inner, outer)
    }

    /// Bubble diameter in points, legacy **~20...60** range (slightly widened for hash endpoints).
    static func bubbleDiameterPoints(minSide: CGFloat, hash: CGFloat) -> CGFloat {
        let t = 18 + 44 * hash
        return max(12, min(t, minSide * 0.22))
    }

    /// Legacy **`scaleEffect`**: start **0.5...1.0**, end **1.2** over the rise leg.
    static func bubbleScale(progress: CGFloat, travel: CGFloat, hash: CGFloat) -> CGFloat {
        let t01 = max(0, min(1, progress / max(travel, 1)))
        let start = 0.5 + 0.5 * hash
        let end: CGFloat = 1.2
        return start + (end - start) * t01
    }

    static func paletteIndex(hash: CGFloat) -> Int {
        min(paletteCount - 1, Int(hash * CGFloat(paletteCount)))
    }
}

/// How the bubble layer is mounted for the current pause / accessibility state.
/// Motion is drawn by a UIKit view + **`CADisplayLink`** (not SwiftUI `TimelineView` / `Canvas`),
/// which kept freezing across tab and navigation switches.
/// Explicitly **`nonisolated`** so unit tests can compare modes without MainActor isolation.
nonisolated enum WaterBubbleTimelineMode: Sendable, Equatable, CustomStringConvertible {
    /// Reduce Motion — no bubbles at all.
    case hidden
    /// Paused — one static frame, display link stopped.
    case staticFrame
    /// Running — `CADisplayLink` on the common run loop (~30 fps).
    case animating

    nonisolated var description: String {
        switch self {
        case .hidden: "hidden"
        case .staticFrame: "staticFrame"
        case .animating: "animating"
        }
    }

    nonisolated static func resolve(reduceMotion: Bool, animationPaused: Bool) -> Self {
        if reduceMotion { return .hidden }
        return animationPaused ? .staticFrame : .animating
    }
}

/// Bubble animation density — standard UI vs denser burst (reserved for future use).
enum WaterBubbleAnimationIntensity: Sendable {
    case standard
    case celebration
    /// Depth-profile above-curve fill — same motion as standard bubbles scaled **~7×** smaller.
    case chartUnderfill

    nonisolated var bubbleCount: Int {
        switch self {
        case .standard: 12
        case .celebration: 30
        case .chartUnderfill: 10
        }
    }

    nonisolated var speedMultiplier: CGFloat {
        switch self {
        case .standard: 1
        case .celebration: 2.5
        case .chartUnderfill: 0.85
        }
    }

    nonisolated var diameterMultiplier: CGFloat {
        switch self {
        case .standard: 1
        case .celebration: 1.2
        case .chartUnderfill: 1.0 / 7.0
        }
    }
}

/// Rising water bubbles drawn in UIKit (`CADisplayLink` + `draw(_:)`).
/// Fill styling follows legacy **`AnimatedBackground`** bubbles (two-stop radial on accent family).
/// Hidden entirely when Reduce Motion is enabled.
struct WaterBubbleBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    /// Caller pause (Search idle defer, chart scrub, off-tab via **`RootTabSelectionStore`**).
    /// Selection is synced from UIKit `didSelect` so idle tabs can stop their display links.
    var animationPaused: Bool = false
    var intensity: WaterBubbleAnimationIntensity = .standard
    /// When set, overrides `intensity.bubbleCount`.
    var bubbleCount: Int?
    /// When set, overrides `intensity.speedMultiplier`.
    var speedMultiplier: CGFloat?
    /// When **`false`**, only the bubble canvas is drawn (for clipped chart underlays).
    var showsBackdrop: Bool = true
    /// DEBUG console site tag (e.g. **`FieldGuide`**, **`Logbook`**).
    var diagnosticsLabel: String = "WaterBubble"

    private var isEffectivelyPaused: Bool {
        animationPaused || scenePhase != .active
    }

    private var timelineMode: WaterBubbleTimelineMode {
        WaterBubbleTimelineMode.resolve(
            reduceMotion: reduceMotion,
            animationPaused: isEffectivelyPaused
        )
    }

    var body: some View {
        ZStack {
            if showsBackdrop {
                AppTheme.Colors.waterBubbleBackdrop
                    .ignoresSafeArea()
            }

            if timelineMode != .hidden {
                WaterBubbleUIKitCanvas(
                    isAnimating: timelineMode == .animating,
                    intensity: intensity,
                    bubbleCount: bubbleCount,
                    speedMultiplier: speedMultiplier,
                    diagnosticsLabel: diagnosticsLabel
                )
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear {
            WaterBubbleDiagnostics.mode(
                label: diagnosticsLabel,
                mode: timelineMode.description,
                animationPaused: isEffectivelyPaused,
                reduceMotion: reduceMotion
            )
        }
        .onChange(of: timelineMode) { _, mode in
            WaterBubbleDiagnostics.mode(
                label: diagnosticsLabel,
                mode: mode.description,
                animationPaused: isEffectivelyPaused,
                reduceMotion: reduceMotion
            )
        }
    }
}

// MARK: - UIKit canvas + display link

private struct WaterBubbleUIKitCanvas: UIViewRepresentable {
    var isAnimating: Bool
    var intensity: WaterBubbleAnimationIntensity
    var bubbleCount: Int?
    var speedMultiplier: CGFloat?
    var diagnosticsLabel: String

    func makeUIView(context: Context) -> WaterBubbleCanvasUIView {
        let view = WaterBubbleCanvasUIView()
        apply(to: view)
        return view
    }

    func updateUIView(_ uiView: WaterBubbleCanvasUIView, context: Context) {
        apply(to: uiView)
    }

    static func dismantleUIView(_ uiView: WaterBubbleCanvasUIView, coordinator: ()) {
        uiView.setAnimating(false)
    }

    private func apply(to view: WaterBubbleCanvasUIView) {
        view.diagnosticsLabel = diagnosticsLabel
        view.intensity = intensity
        view.bubbleCountOverride = bubbleCount
        view.speedMultiplierOverride = speedMultiplier
        view.setAnimating(isAnimating)
    }
}

private final class WaterBubbleCanvasUIView: UIView {
    var intensity: WaterBubbleAnimationIntensity = .standard
    var bubbleCountOverride: Int?
    var speedMultiplierOverride: CGFloat?
    var diagnosticsLabel: String = "WaterBubble"

    private var displayLink: CADisplayLink?
    private var isAnimating = false
    private var frameTime = Date.timeIntervalSinceReferenceDate
    private var tickCount: UInt64 = 0
    private var lastHeartbeatTick: UInt64 = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw
        clearsContextBeforeDrawing = true
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: WaterBubbleCanvasUIView, _) in
            view.setNeedsDisplay()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        displayLink?.invalidate()
    }

    func setAnimating(_ running: Bool) {
        if running {
            let wasRunning = isAnimating && displayLink != nil
            isAnimating = true
            startDisplayLinkIfNeeded()
            if !wasRunning {
                WaterBubbleDiagnostics.hostUpdate(
                    label: diagnosticsLabel,
                    isAnimating: true,
                    size: bounds.size
                )
            }
        } else {
            let wasRunning = isAnimating || displayLink != nil
            isAnimating = false
            stopDisplayLink()
            frameTime = Date.timeIntervalSinceReferenceDate
            setNeedsDisplay()
            if wasRunning {
                WaterBubbleDiagnostics.hostUpdate(
                    label: diagnosticsLabel,
                    isAnimating: false,
                    size: bounds.size
                )
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Bounds often start at 0 — redraw once we have a real size.
        if bounds.width > 1, bounds.height > 1 {
            setNeedsDisplay()
        }
    }

    private func startDisplayLinkIfNeeded() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 24, maximum: 30, preferred: 30)
        link.add(to: .main, forMode: .common)
        displayLink = link
        tickCount = 0
        lastHeartbeatTick = 0
        frameTime = Date.timeIntervalSinceReferenceDate
        WaterBubbleDiagnostics.linkStart(label: diagnosticsLabel, bounds: bounds.size)
        setNeedsDisplay()
    }

    private func stopDisplayLink() {
        guard displayLink != nil else { return }
        displayLink?.invalidate()
        displayLink = nil
        WaterBubbleDiagnostics.linkStop(label: diagnosticsLabel)
    }

    @objc private func step(_ link: CADisplayLink) {
        frameTime = Date.timeIntervalSinceReferenceDate
        tickCount += 1
        if tickCount &- lastHeartbeatTick >= 30 {
            lastHeartbeatTick = tickCount
            WaterBubbleDiagnostics.heartbeat(
                label: diagnosticsLabel,
                ticks: tickCount,
                time: frameTime,
                bounds: bounds.size
            )
        }
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let size = bounds.size
        WaterBubbleDiagnostics.draw(
            label: diagnosticsLabel,
            size: size,
            time: frameTime,
            animating: isAnimating
        )
        WaterBubbleUIKitDrawing.drawBubbles(
            in: context,
            size: size,
            time: frameTime,
            intensity: intensity,
            bubbleCount: bubbleCountOverride,
            speedMultiplier: speedMultiplierOverride
        )
    }
}

/// Core Graphics bubble fill (same math as the former SwiftUI `Canvas` path).
enum WaterBubbleUIKitDrawing {
    private static var palette: [UIColor] {
        [
            UIColor(AppTheme.Colors.accent),
            UIColor(AppTheme.Colors.accentLight),
            UIColor(AppTheme.Colors.accentDeep),
        ]
    }

    static func drawBubbles(
        in context: CGContext,
        size: CGSize,
        time: TimeInterval,
        intensity: WaterBubbleAnimationIntensity,
        bubbleCount: Int?,
        speedMultiplier: CGFloat?
    ) {
        guard size.width > 1, size.height > 1 else { return }

        let t = CGFloat(time)
        let minSide = min(size.width, size.height)
        let resolvedBubbleCount = bubbleCount ?? intensity.bubbleCount
        let speedScale = speedMultiplier ?? intensity.speedMultiplier
        let diameterScale = intensity.diameterMultiplier
        let colors = palette

        for i in 0..<resolvedBubbleCount {
            let xNorm = hash01(i, 1)
            let speed = (10 + 22 * hash01(i, 3)) * speedScale
            let phaseY = (size.height + 80) * hash01(i, 4)
            let phaseWobble = .pi * 2 * hash01(i, 5)
            let wobbleAmp = minSide * (0.018 + 0.035 * hash01(i, 6))

            let diameter = WaterBubbleRendering.bubbleDiameterPoints(
                minSide: minSide,
                hash: hash01(i, 2)
            ) * diameterScale
            let maxRadius = diameter * 1.2 / 2
            let travel = size.height + maxRadius * 2 + 40
            let progress = mod(t * speed + phaseY, m: travel)
            let scale = WaterBubbleRendering.bubbleScale(
                progress: progress,
                travel: travel,
                hash: hash01(i, 8)
            )
            let r = (diameter * scale) / 2

            let centerY = size.height + r - progress
            let centerX = xNorm * size.width + sin(t * 0.45 + phaseWobble) * wobbleAmp
            let center = CGPoint(x: centerX, y: centerY)

            let paletteIdx = WaterBubbleRendering.paletteIndex(hash: hash01(i, 20))
            let base = colors[paletteIdx]
            let op = WaterBubbleRendering.bubbleOpacities(hash: hash01(i, 7))
            let inner = base.withAlphaComponent(op.inner)
            let outer = base.withAlphaComponent(op.outer)

            let space = CGColorSpaceCreateDeviceRGB()
            let gradientColors = [inner.cgColor, outer.cgColor] as CFArray
            guard let gradient = CGGradient(
                colorsSpace: space,
                colors: gradientColors,
                locations: [0, 1]
            ) else { continue }

            context.saveGState()
            context.addEllipse(in: CGRect(
                x: center.x - r,
                y: center.y - r,
                width: r * 2,
                height: r * 2
            ))
            context.clip()
            context.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: r,
                options: []
            )
            context.restoreGState()
        }
    }

    private static func hash01(_ index: Int, _ salt: Int) -> CGFloat {
        let x = sin(Double(index * 127 + salt * 19)) * 43758.5453
        return CGFloat(x - floor(x))
    }

    private static func mod(_ a: CGFloat, m: CGFloat) -> CGFloat {
        let r = a.truncatingRemainder(dividingBy: m)
        return r < 0 ? r + m : r
    }
}

/// Profile-style decorative stack: rising bubbles plus the semitransparent ocean scrim.
/// Shared by **`ProfileView`** and **`GlobalSearchView`** idle state.
struct ProfileBubbleBackgroundLayer: View {
    var animationPaused: Bool = false
    var diagnosticsLabel: String = "Profile"

    var body: some View {
        Group {
            if !GoDiveUITestConfiguration.isActive {
                WaterBubbleBackground(
                    animationPaused: animationPaused,
                    diagnosticsLabel: diagnosticsLabel
                )
                AppTheme.Colors.profileBubbleScrim
                    .ignoresSafeArea()
            }
        }
    }
}

#Preview("Bubbles") {
    ZStack {
        AppTheme.Colors.screenBackgroundGradient
        WaterBubbleBackground(diagnosticsLabel: "Preview")
    }
    .ignoresSafeArea()
}
