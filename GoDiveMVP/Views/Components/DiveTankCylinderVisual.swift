import SwiftUI

// MARK: - Shapes

/// Main cylinder body: flat top, rounded bottom corners (reference silhouette).
private struct DiveTankBodyOutlineShape: Shape {
    var bottomCornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(max(bottomCornerRadius, 0), rect.width / 2, rect.height / 2)
        var path = Path()

        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(
            center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
            radius: r,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: r, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: r, y: rect.maxY - r),
            radius: r,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: 0, y: 0))
        return path
    }
}

/// Semicircular cap: flat edge at **`rect.maxY`**, arc bulges toward **`rect.minY`**.
private struct DiveTankDomeCapShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = rect.width / 2
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.maxY),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - View

/// Minimal scuba cylinder (reference-style silhouette): body + gap + dome + valve.
/// **`pressureRemainingFraction`** is **end/start** PSI (**0...1**): gas column is bottom-anchored; yellow/green band ratio is unchanged within the visible gas.
struct DiveTankCylinderVisual: View {
    /// Overall height of the drawn tank in points.
    var height: CGFloat = 220

    /// **0...1** — remaining pressure (**ending / beginning**). **1** = visually full.
    var pressureRemainingFraction: CGFloat = 1

    private let yellowFill = Color(red: 0.92, green: 0.78, blue: 0.12)
    private let greenFill = Color(red: 0.14, green: 0.55, blue: 0.38)
    private let outlineColor = Color.primary.opacity(0.24)
    private let outlineWidth: CGFloat = 1.25

    /// Fraction of the **gas column** (not the whole body) that is green at the top — same at every fill level.
    private let greenBodyFillFraction: CGFloat = 0.27

    var body: some View {
        let fill = min(1, max(0, pressureRemainingFraction))
        let frameW = height * 0.34
        let bodyW = frameW * 0.9
        let bottomR = min(bodyW * 0.2, height * 0.065)
        let valveH = height * 0.048
        let stemW = max(2, bodyW * 0.09)
        let knobW = bodyW * 0.26
        let knobH = max(2, valveH * 0.32)
        let gapH = max(2, height * 0.014)
        let domeH = bodyW * 0.5
        let crownH = valveH + domeH
        let bodyH = height - crownH - gapH

        VStack(spacing: 0) {
            valveAndDome(
                bodyWidth: bodyW,
                valveHeight: valveH,
                domeHeight: domeH,
                stemWidth: stemW,
                knobW: knobW,
                knobH: knobH,
                domeFillFraction: fill
            )

            Color.clear
                .frame(height: gapH)

            bodyColumn(
                width: bodyW,
                height: bodyH,
                bottomCornerRadius: bottomR,
                fillFraction: fill
            )
        }
        .frame(width: frameW, height: height)
    }

    @ViewBuilder
    private func valveAndDome(
        bodyWidth: CGFloat,
        valveHeight: CGFloat,
        domeHeight: CGFloat,
        stemWidth: CGFloat,
        knobW: CGFloat,
        knobH: CGFloat,
        domeFillFraction: CGFloat
    ) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: stemWidth * 0.22, style: .continuous)
                    .fill(outlineColor)
                    .frame(width: stemWidth, height: max(2, valveHeight - knobH - 1))
                    .padding(.top, knobH + 1)

                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: knobH * 0.25, style: .continuous)
                        .fill(outlineColor)
                        .frame(width: knobW, height: knobH)
                        .padding(.leading, bodyWidth * 0.12)
                    Spacer(minLength: 0)
                }
            }
            .frame(height: valveHeight)
            .frame(maxWidth: bodyWidth)

            ZStack {
                DiveTankDomeCapShape()
                    .fill(greenFill.opacity(0.92 * min(1, max(0, domeFillFraction))))

                DiveTankDomeCapShape()
                    .stroke(outlineColor, lineWidth: outlineWidth)
            }
            .frame(width: bodyWidth, height: domeHeight)
        }
        .frame(width: bodyWidth)
    }

    private func bodyColumn(width: CGFloat, height: CGFloat, bottomCornerRadius: CGFloat, fillFraction: CGFloat) -> some View {
        let f = min(1, max(0, fillFraction))
        let gasH = height * f
        let greenGasH = gasH * greenBodyFillFraction
        let yellowGasH = max(0, gasH - greenGasH)

        return ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                greenFill
                    .opacity(0.92)
                    .frame(height: greenGasH)
                yellowFill
                    .opacity(0.9)
                    .frame(height: yellowGasH)
            }
            .frame(height: gasH)
            .frame(maxWidth: .infinity, maxHeight: height, alignment: .bottom)

            DiveTankBodyOutlineShape(bottomCornerRadius: bottomCornerRadius)
                .stroke(outlineColor, lineWidth: outlineWidth)
        }
        .frame(width: width, height: height)
        .clipShape(DiveTankBodyOutlineShape(bottomCornerRadius: bottomCornerRadius))
    }
}
