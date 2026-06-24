import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// One swipeable MacDive import instruction page (compact screenshot + copy, no scroll).
struct MacDiveUddfImportStepPage: View {
    let step: MacDiveUddfImportPresentation.Step
    let stepIndex: Int
    let stepCount: Int

    private var showsScreenshot: Bool {
        MacDiveUddfImportScreenshot.hasAsset(named: step.screenshotAssetName) || !step.showsImportButton
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("\(step.stepLabel) of \(stepCount)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.mutedText)
                .textCase(.uppercase)
                .tracking(0.6)

            Text(step.title)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(step.detail)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            if showsScreenshot {
                screenshotCard
                    .padding(.top, AppTheme.Spacing.sm)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, AppTheme.Spacing.sm)
        .padding(.bottom, AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(step.stepLabel) of \(stepCount). \(step.title). \(step.detail)")
    }

    @ViewBuilder
    private var screenshotCard: some View {
        Group {
            if MacDiveUddfImportScreenshot.hasAsset(named: step.screenshotAssetName) {
                Image(step.screenshotAssetName)
                    .resizable()
                    .scaledToFit()
            } else {
                screenshotPlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: MacDiveUddfImportPresentation.Layout.screenshotMaxHeight)
        .padding(AppTheme.Spacing.sm)
        .background {
            RoundedRectangle(
                cornerRadius: MacDiveUddfImportPresentation.Layout.screenshotCornerRadius,
                style: .continuous
            )
            .fill(AppTheme.Colors.surfaceElevated)
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: MacDiveUddfImportPresentation.Layout.screenshotCornerRadius,
                style: .continuous
            )
            .stroke(AppTheme.Colors.tabUnselected.opacity(0.16), lineWidth: 1)
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: MacDiveUddfImportPresentation.Layout.screenshotCornerRadius,
                style: .continuous
            )
        )
        .accessibilityLabel("Screenshot for \(step.title)")
    }

    private var screenshotPlaceholder: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(AppTheme.Colors.tabUnselected)

            Text("Screenshot")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.mutedText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum MacDiveUddfImportScreenshot {
    nonisolated static func hasAsset(named name: String) -> Bool {
        guard !name.isEmpty else { return false }
        #if canImport(UIKit)
        return UIImage(named: name) != nil
        #else
        return false
        #endif
    }
}
