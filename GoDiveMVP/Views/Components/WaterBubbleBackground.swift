import SwiftUI

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

/// Bubble animation density — standard UI vs post-sign-in celebration burst.
enum WaterBubbleAnimationIntensity: Sendable {
    case standard
    case celebration

    nonisolated var bubbleCount: Int {
        switch self {
        case .standard: 12
        case .celebration: 30
        }
    }

    nonisolated var speedMultiplier: CGFloat {
        switch self {
        case .standard: 1
        case .celebration: 2.5
        }
    }

    nonisolated var diameterMultiplier: CGFloat {
        switch self {
        case .standard: 1
        case .celebration: 1.2
        }
    }
}

/// Rising water bubbles drawn in a single `Canvas`, driven by `TimelineView`.
/// Fill styling follows legacy **`AnimatedBackground`** bubbles (two-stop radial on accent family), without the old `Timer` / `ForEach` stack.
/// Hidden entirely when Reduce Motion is enabled.
/// Expands past safe areas so motion reads edge-to-edge (under status bar, home indicator, tab bar).
struct WaterBubbleBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Pauses **`TimelineView`** during heavy logbook store work so the main thread stays responsive.
    var animationPaused: Bool = false
    var intensity: WaterBubbleAnimationIntensity = .standard
    /// When set, overrides `intensity.speedMultiplier` (e.g. animated ramp on sign-in celebration).
    var speedMultiplier: CGFloat?

    var body: some View {
        ZStack {
            AppTheme.Colors.waterBubbleBackdrop
                .ignoresSafeArea()

            Group {
                if reduceMotion {
                    Color.clear
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: animationPaused)) { timeline in
                        Canvas { context, size in
                            Self.drawBubbles(
                                in: &context,
                                size: size,
                                time: timeline.date.timeIntervalSinceReferenceDate,
                                intensity: intensity,
                                speedMultiplier: speedMultiplier
                            )
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    private static let bubblePalette: [Color] = [
        AppTheme.Colors.accent,
        AppTheme.Colors.accentLight,
        AppTheme.Colors.accentDeep,
    ]

    private static func drawBubbles(
        in context: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval,
        intensity: WaterBubbleAnimationIntensity,
        speedMultiplier: CGFloat?
    ) {
        guard size.width > 1, size.height > 1 else { return }

        let t = CGFloat(time)
        let minSide = min(size.width, size.height)
        let bubbleCount = intensity.bubbleCount
        let speedScale = speedMultiplier ?? intensity.speedMultiplier
        let diameterScale = intensity.diameterMultiplier

        for i in 0..<bubbleCount {
            let xNorm = hash01(i, 1)
            let speed = (10 + 22 * hash01(i, 3)) * speedScale
            let phaseY = (size.height + 80) * hash01(i, 4)
            let phaseWobble = .pi * 2 * hash01(i, 5)
            let wobbleAmp = minSide * (0.018 + 0.035 * hash01(i, 6))

            let diameter = WaterBubbleRendering.bubbleDiameterPoints(
                minSide: minSide,
                hash: hash01(i, 2)
            ) * diameterScale
            // Keep loop length stable vs scaled radius (legacy `scaleEffect` grows to **1.2**).
            let maxRadius = diameter * 1.2 / 2
            let travel = size.height + maxRadius * 2 + 40
            let progress = mod(t * speed + phaseY, m: travel)
            let scale = WaterBubbleRendering.bubbleScale(progress: progress, travel: travel, hash: hash01(i, 8))
            let r = (diameter * scale) / 2

            let centerY = size.height + r - progress
            let centerX = xNorm * size.width + sin(t * 0.45 + phaseWobble) * wobbleAmp

            let rect = CGRect(x: centerX - r, y: centerY - r, width: r * 2, height: r * 2)
            let circle = Circle().path(in: rect)

            let paletteIdx = WaterBubbleRendering.paletteIndex(hash: hash01(i, 20))
            let base = bubblePalette[paletteIdx]
            let op = WaterBubbleRendering.bubbleOpacities(hash: hash01(i, 7))
            let inner = base.opacity(Double(op.inner))
            let outer = base.opacity(Double(op.outer))
            let shading = Gradient(colors: [inner, outer])

            context.fill(
                circle,
                with: .radialGradient(
                    shading,
                    center: CGPoint(x: centerX, y: centerY),
                    startRadius: 0,
                    endRadius: r
                )
            )
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

    var body: some View {
        Group {
            if !GoDiveUITestConfiguration.isActive {
                WaterBubbleBackground(animationPaused: animationPaused)
                AppTheme.Colors.profileBubbleScrim
                    .ignoresSafeArea()
            }
        }
    }
}

#Preview("Bubbles") {
    ZStack {
        AppTheme.Colors.screenBackgroundGradient
        WaterBubbleBackground()
    }
    .ignoresSafeArea()
}
