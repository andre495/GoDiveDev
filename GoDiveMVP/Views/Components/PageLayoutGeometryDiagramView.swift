import SwiftUI

/// Schematic hero + sheet regions (reference guide and live overlay).
struct PageLayoutGeometryDiagramView: View {
    enum Style {
        case overlay
        case reference
    }

    let snapshot: PageLayoutGeometrySnapshot
    var style: Style = .overlay

    private var diagramScale: CGFloat {
        switch style {
        case .overlay: 1
        case .reference: 0.42
        }
    }

    private var diagramWidth: CGFloat {
        switch style {
        case .overlay: snapshot.screenWidth
        case .reference: snapshot.screenWidth
        }
    }

    private var diagramHeight: CGFloat {
        max(snapshot.geometryHeight * diagramScale, 1)
    }

    var body: some View {
        Group {
            switch style {
            case .overlay:
                regionGuides
                    .frame(width: diagramWidth, height: diagramHeight, alignment: .top)
                    .clipped()
            case .reference:
                referenceDiagramCard
            }
        }
        .accessibilityIdentifier("PageLayoutGeometry.Diagram.\(snapshot.pageKind.rawValue)")
    }

    private var referenceDiagramCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppTheme.Colors.tabUnselected.opacity(0.35), lineWidth: 1)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.Colors.tabUnselected.opacity(0.06))
                }
                .frame(width: diagramWidth, height: diagramHeight)
                .overlay(alignment: .top) {
                    scaledDiagram
                }
                .overlay(alignment: .bottomLeading) {
                    Text("geometry.height \(Int(snapshot.geometryHeight))")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .padding(8)
                }

            referenceAnnotations
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var scaledDiagram: some View {
        regionGuides
            .scaleEffect(diagramScale, anchor: .top)
            .frame(width: diagramWidth, height: diagramHeight, alignment: .top)
            .clipped()
    }

    @ViewBuilder
    private var regionGuides: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                Color.blue.opacity(style == .reference ? 0.22 : 0.14)
                    .frame(height: snapshot.heroHeight)
                    .overlay(alignment: .bottomLeading) {
                        regionLabel("hero", value: snapshot.heroHeight)
                            .padding(6)
                    }

                Color.green.opacity(style == .reference ? 0.18 : 0.10)
                    .frame(height: snapshot.sheetBodyHeight)
                    .overlay(alignment: .topLeading) {
                        regionLabel("sheet.body", value: snapshot.sheetBodyHeight)
                            .padding(6)
                    }
            }
            .frame(height: snapshot.layoutStackHeight, alignment: .top)
            .overlay(alignment: .bottomLeading) {
                if style == .reference {
                    regionLabel("layout.stack", value: snapshot.layoutStackHeight)
                        .padding(6)
                }
            }

            Rectangle()
                .fill(Color.red.opacity(0.9))
                .frame(height: style == .reference ? 3 : 2)
                .offset(y: snapshot.sheetSeamY)
                .overlay(alignment: .leading) {
                    seamLabels
                        .padding(.leading, 6)
                        .offset(y: snapshot.sheetSeamY - (style == .reference ? 36 : 28))
                }

            if snapshot.tabBarReserveBelowStack > 0.5 {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Color.orange.opacity(style == .reference ? 0.28 : 0.18)
                        .frame(height: snapshot.tabBarReserveBelowStack)
                        .overlay(alignment: .topLeading) {
                            regionLabel(
                                "tabBar.reserve",
                                value: snapshot.tabBarReserveBelowStack
                            )
                            .padding(6)
                        }
                }
                .frame(height: snapshot.geometryHeight, alignment: .top)
            }
        }
        .frame(width: snapshot.screenWidth, height: snapshot.geometryHeight, alignment: .top)
    }

    @ViewBuilder
    private var seamLabels: some View {
        if style == .reference {
            VStack(alignment: .leading, spacing: 3) {
                regionLabel("stackTop", value: snapshot.sheetSeamY)
                regionLabel("stackBot", value: snapshot.sheetSeamYFromStackBottom)
                regionLabel("screenBot", value: snapshot.sheetSeamYFromScreenBottom)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                regionLabel("stackTop", value: snapshot.sheetSeamY)
                regionLabel("stackBot", value: snapshot.sheetSeamYFromStackBottom)
                regionLabel("screenBot", value: snapshot.sheetSeamYFromScreenBottom)
            }
        }
    }

    @ViewBuilder
    private var referenceAnnotations: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            annotationRow(
                color: .blue,
                title: "Hero",
                detail: "hero.height"
            )
            annotationRow(
                color: .red,
                title: "Sheet seam",
                detail: "sheet.seamYFromStackTop"
            )
            annotationRow(
                color: .green,
                title: "Sheet body",
                detail: "sheet.body.height"
            )
            if snapshot.tabBarReserveBelowStack > 0.5 {
                annotationRow(
                    color: .orange,
                    title: "Tab bar reserve",
                    detail: "tabBar.reserveBelowStack"
                )
            }
        }
        .padding(.top, diagramHeight + AppTheme.Spacing.md)
    }

    private func annotationRow(color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
    }

    private func regionLabel(_ name: String, value: CGFloat) -> some View {
        Text("\(name) \(String(format: "%.0f", value))")
            .font(.system(size: style == .reference ? 11 : 10, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.black.opacity(0.55), in: Capsule())
            .foregroundStyle(.white)
    }
}
