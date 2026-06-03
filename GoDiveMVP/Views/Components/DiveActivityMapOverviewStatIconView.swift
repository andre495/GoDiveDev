import SwiftUI

/// Decorative icons for **`DiveActivityMapOverviewStatsBox`** side stats.
struct DiveActivityMapOverviewStatIconView: View {
    let icon: DiveActivityOverviewPresentation.MapOverviewStatIcon
    var size: CGFloat = 38

    var body: some View {
        Group {
            switch icon {
            case .clock:
                DiveMapOverviewClockIcon(fontSize: size * 0.6)
            case .palmTree:
                DiveMapOverviewPalmTreeIcon()
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Depth column visual

/// Simple water column: blue fill to max depth, dashed line for average depth.
struct DiveMapOverviewDepthProfileVisual: View {
    let maxDepthFraction: Double
    let avgDepthFraction: Double
    let showsAverageLine: Bool
    var width: CGFloat = 18
    var height: CGFloat = 76

    private var clampedMaxDepth: CGFloat {
        CGFloat(min(max(maxDepthFraction, 0), 1))
    }

    private var clampedAvgDepth: CGFloat {
        CGFloat(min(max(avgDepthFraction, 0), 1))
    }

    var body: some View {
        let columnHeight = height * 0.9

        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: width * 0.18, style: .continuous)
                .fill(AppTheme.Colors.accent.opacity(0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: width * 0.18, style: .continuous)
                        .stroke(AppTheme.Colors.tabUnselected.opacity(0.4), lineWidth: max(1.5, width * 0.045))
                }
                .frame(width: width, height: columnHeight)

            RoundedRectangle(cornerRadius: width * 0.14, style: .continuous)
                .fill(AppTheme.Colors.accent.opacity(0.75))
                .frame(width: width - 4, height: max(3, (columnHeight - 4) * clampedMaxDepth))
                .padding(.bottom, 2)

            if showsAverageLine, clampedAvgDepth > 0 {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: width + 6, height: max(2, width * 0.08))
                    .padding(.bottom, 2 + (columnHeight - 4) * clampedAvgDepth)
            }
        }
        .frame(width: width + 6, height: height, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

// MARK: - Clock

private struct DiveMapOverviewClockIcon: View {
    var fontSize: CGFloat = 34

    var body: some View {
        Image(systemName: "clock.fill")
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(AppTheme.Colors.accent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Palm tree

private struct DiveMapOverviewPalmTreeIcon: View {
    var body: some View {
        Canvas { context, size in
            let groundY = size.height * 0.84
            let trunkColor = AppTheme.Colors.secondaryText.opacity(0.85)
            let frondColor = AppTheme.Colors.accent
            let frondLineWidth = max(2.4, size.width * 0.043)

            var ground = Path()
            ground.move(to: CGPoint(x: size.width * 0.1, y: groundY))
            ground.addQuadCurve(
                to: CGPoint(x: size.width * 0.9, y: groundY),
                control: CGPoint(x: size.width * 0.5, y: groundY + size.height * 0.04)
            )
            context.stroke(
                ground,
                with: .color(trunkColor),
                style: StrokeStyle(lineWidth: max(1.5, size.width * 0.035), lineCap: .round)
            )

            let trunkTop = CGPoint(x: size.width * 0.47, y: size.height * 0.5)
            let trunkBase = CGPoint(x: size.width * 0.56, y: groundY - 1)
            let topHalfWidth = size.width * 0.055
            let baseHalfWidth = size.width * 0.085

            var trunk = Path()
            trunk.move(to: CGPoint(x: trunkTop.x - topHalfWidth, y: trunkTop.y))
            trunk.addQuadCurve(
                to: CGPoint(x: trunkBase.x - baseHalfWidth, y: trunkBase.y),
                control: CGPoint(x: trunkTop.x - baseHalfWidth * 1.1, y: (trunkTop.y + trunkBase.y) * 0.56)
            )
            trunk.addQuadCurve(
                to: CGPoint(x: trunkBase.x + baseHalfWidth, y: trunkBase.y),
                control: CGPoint(x: trunkBase.x, y: trunkBase.y + size.height * 0.015)
            )
            trunk.addQuadCurve(
                to: CGPoint(x: trunkTop.x + topHalfWidth, y: trunkTop.y),
                control: CGPoint(x: trunkTop.x + baseHalfWidth * 1.05, y: (trunkTop.y + trunkBase.y) * 0.58)
            )
            trunk.closeSubpath()
            context.fill(trunk, with: .color(trunkColor))

            let crownCenter = CGPoint(x: trunkTop.x, y: trunkTop.y - size.height * 0.02)
            let frondSpecs: [(angle: Double, length: CGFloat)] = [
                (-118, size.width * 0.34),
                (-68, size.width * 0.36),
                (-22, size.width * 0.33),
                (28, size.width * 0.33),
                (78, size.width * 0.36),
                (128, size.width * 0.34),
            ]

            for spec in frondSpecs {
                var frond = Path()
                frond.move(to: crownCenter)
                let radians = spec.angle * .pi / 180
                let tip = CGPoint(
                    x: crownCenter.x + cos(radians) * spec.length,
                    y: crownCenter.y + sin(radians) * spec.length * 0.72
                )
                let control = CGPoint(
                    x: crownCenter.x + cos(radians) * spec.length * 0.55,
                    y: crownCenter.y + sin(radians) * spec.length * 0.35 - 2
                )
                frond.addQuadCurve(to: tip, control: control)
                context.stroke(
                    frond,
                    with: .color(frondColor),
                    style: StrokeStyle(lineWidth: frondLineWidth, lineCap: .round)
                )
            }

            let crownSize = size.width * 0.125
            context.fill(
                Path(ellipseIn: CGRect(
                    x: crownCenter.x - crownSize / 2,
                    y: crownCenter.y - crownSize * 0.5,
                    width: crownSize,
                    height: crownSize * 0.86
                )),
                with: .color(frondColor.opacity(0.9))
            )
        }
    }
}

#if DEBUG
#Preview("Map overview stat icons") {
    VStack(spacing: 24) {
        HStack(spacing: 20) {
            DiveActivityMapOverviewStatIconView(icon: .clock)
            DiveActivityMapOverviewStatIconView(icon: .palmTree)
        }

        DiveMapOverviewDepthProfileVisual(
            maxDepthFraction: 0.46,
            avgDepthFraction: 0.30,
            showsAverageLine: true,
            width: 40,
            height: 168
        )
        .padding(.horizontal, 40)
    }
    .padding()
}
#endif
