import SwiftUI

/// Swipeable MacDive export instructions on a pushed **AppPage**; the last page opens the UDDF file picker.
struct MacDiveUddfImportGuideView: View {
    let onChooseFile: () -> Void
    var showsBackButton: Bool = true
    var skipButtonTitle: String? = nil
    var skipButtonAccessibilityIdentifier: String? = nil
    var onSkip: (() -> Void)? = nil

    @State private var pageIndex = 0

    private var steps: [MacDiveUddfImportPresentation.Step] {
        MacDiveUddfImportPresentation.steps
    }

    private var showsImportButton: Bool {
        MacDiveUddfImportPresentation.step(at: pageIndex)?.showsImportButton == true
    }

    var body: some View {
        AppPage(
            title: "MacDive import",
            showsBackButton: showsBackButton,
            showsBrandWordmark: false,
            trailingContent: {
                if let skipButtonTitle, let onSkip {
                    Button(skipButtonTitle, action: onSkip)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.accentDeep)
                        .accessibilityIdentifier(skipButtonAccessibilityIdentifier ?? "MacDiveUddfImportGuide.Skip")
                }
            }
        ) {
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
        .appOnboardingPrimaryGlassButtonStyle()
        .accessibilityIdentifier("MacDiveUddfImportGuide.ImportMacDiveData")
    }
}

#Preview {
    NavigationStack {
        MacDiveUddfImportGuideView(onChooseFile: {})
    }
}
