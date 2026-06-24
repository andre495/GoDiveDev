import SwiftUI

/// Swipeable MacDive export instructions on a pushed **AppPage**; the last page opens the UDDF file picker.
struct MacDiveUddfImportGuideView: View {
    let onChooseFile: () -> Void

    @State private var pageIndex = 0

    private var steps: [MacDiveUddfImportPresentation.Step] {
        MacDiveUddfImportPresentation.steps
    }

    private var showsImportButton: Bool {
        MacDiveUddfImportPresentation.step(at: pageIndex)?.showsImportButton == true
    }

    var body: some View {
        AppPage(title: "MacDive import", showsBackButton: true) {
            VStack(spacing: 0) {
                TabView(selection: $pageIndex) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        MacDiveUddfImportStepPage(
                            step: step,
                            stepIndex: index,
                            stepCount: steps.count
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .animation(.easeInOut(duration: 0.2), value: pageIndex)

                if showsImportButton {
                    importButton
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.top, AppTheme.Spacing.sm)
                        .padding(.bottom, AppTheme.Spacing.md)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(.easeInOut(duration: 0.2), value: showsImportButton)
        .hidesBottomTabBarWhenPushed()
    }

    private var importButton: some View {
        Button(MacDiveUddfImportPresentation.importButtonTitle) {
            onChooseFile()
        }
        .font(.body.weight(.semibold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.accent)
        }
        .foregroundStyle(.white)
        .accessibilityIdentifier("MacDiveUddfImportGuide.ImportMacDiveData")
    }
}

#Preview {
    NavigationStack {
        MacDiveUddfImportGuideView(onChooseFile: {})
    }
}
