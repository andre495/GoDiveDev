import SwiftUI

/// On-screen guides + copyable layout report (Settings → Developer → **Show page layout geometry**).
struct PageLayoutGeometryOverlay: View {
    let snapshot: PageLayoutGeometrySnapshot

    @State private var showsReport = true
    @State private var didCopyReport = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            PageLayoutGeometryDiagramView(snapshot: snapshot, style: .overlay)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Text(snapshot.pageKind.displayName)
                        .font(.caption.weight(.bold))
                    Spacer(minLength: 0)
                    Button(showsReport ? "Hide" : "Show") {
                        showsReport.toggle()
                    }
                    .font(.caption.weight(.semibold))
                }

                if showsReport {
                    ScrollView {
                        Text(snapshot.layoutReport())
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 168)

                    Button(didCopyReport ? "Copied" : "Copy layout report") {
                        copyReport()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.Colors.accent)
                }
            }
            .padding(AppTheme.Spacing.sm)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .frame(maxWidth: min(snapshot.screenWidth - 32, 320), alignment: .leading)
            .padding(AppTheme.Spacing.sm)
        }
        .accessibilityIdentifier("PageLayoutGeometry.Overlay.\(snapshot.pageKind.rawValue)")
    }

    private func copyReport() {
        #if canImport(UIKit)
        UIPasteboard.general.string = snapshot.layoutReport()
        #endif
        didCopyReport = true
    }
}

private struct PageLayoutGeometryOverlayModifier: ViewModifier {
    @AppStorage(AppUserSettings.showPageLayoutGeometryOverlayKey)
    private var showsPageLayoutGeometryOverlay = false

    let snapshot: PageLayoutGeometrySnapshot

    func body(content: Content) -> some View {
        content.overlay(alignment: .topLeading) {
            if showsPageLayoutGeometryOverlay {
                PageLayoutGeometryOverlay(snapshot: snapshot)
            }
        }
    }
}

extension View {
    /// Overlays region guides + a copyable layout report when enabled in Settings.
    func pageLayoutGeometryOverlay(_ snapshot: PageLayoutGeometrySnapshot) -> some View {
        modifier(PageLayoutGeometryOverlayModifier(snapshot: snapshot))
    }
}
