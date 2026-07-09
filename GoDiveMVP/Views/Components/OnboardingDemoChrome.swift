import SwiftUI

private enum OnboardingDemoChromeLayout {
  static let strokeOpacity: CGFloat = 0.22

  static func bezelCornerRadius(for phoneWidth: CGFloat) -> CGFloat {
    min(28, max(18, phoneWidth * 0.106))
  }
}

/// iPhone portrait proportions for onboarding micro-demos (logical pt ratio).
enum OnboardingDemoPhoneFrameMetrics: Sendable {
  /// iPhone 17-class logical resolution — width ÷ height in portrait.
  nonisolated static let referenceLogicalSize = CGSize(width: 393, height: 852)

  /// Default onboarding phone preview height (50% larger than the original 300 pt frame).
  nonisolated static let defaultMaxHeight: CGFloat = 450

  nonisolated static var widthOverHeight: CGFloat {
    referenceLogicalSize.width / referenceLogicalSize.height
  }

  nonisolated static func portraitSize(maxHeight: CGFloat) -> CGSize {
    let height = max(1, maxHeight)
    let width = height * widthOverHeight
    return CGSize(width: width, height: height)
  }

  nonisolated static func contentScale(for phoneSize: CGSize) -> CGFloat {
    guard referenceLogicalSize.width > 0 else { return 1 }
    return phoneSize.width / referenceLogicalSize.width
  }
}

/// Clips demo content to a true iPhone-aspect portrait frame.
struct OnboardingDemoPhoneFrame<Content: View>: View {
  let maxHeight: CGFloat
  @ViewBuilder let content: () -> Content

  private var phoneSize: CGSize {
    OnboardingDemoPhoneFrameMetrics.portraitSize(maxHeight: maxHeight)
  }

  private var contentScale: CGFloat {
    OnboardingDemoPhoneFrameMetrics.contentScale(for: phoneSize)
  }

  private var bezelCornerRadius: CGFloat {
    OnboardingDemoChromeLayout.bezelCornerRadius(for: phoneSize.width)
  }

  var body: some View {
    OnboardingDemoChrome(cornerRadius: bezelCornerRadius) {
      content()
        .frame(
          width: OnboardingDemoPhoneFrameMetrics.referenceLogicalSize.width,
          height: OnboardingDemoPhoneFrameMetrics.referenceLogicalSize.height,
          alignment: .top
        )
        .scaleEffect(contentScale, anchor: .top)
        .frame(width: phoneSize.width, height: phoneSize.height, alignment: .top)
        .clipped()
    }
    .frame(width: phoneSize.width, height: phoneSize.height)
  }
}

/// Rounded device frame for onboarding micro-demos (non-interactive marketing previews).
struct OnboardingDemoChrome<Content: View>: View {
  var cornerRadius: CGFloat = OnboardingDemoChromeLayout.bezelCornerRadius(
    for: OnboardingDemoPhoneFrameMetrics.portraitSize(
      maxHeight: OnboardingDemoPhoneFrameMetrics.defaultMaxHeight
    ).width
  )

  @ViewBuilder let content: () -> Content

  var body: some View {
    content()
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .background {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(AppTheme.Colors.surfaceElevated)
      }
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .strokeBorder(
            AppTheme.Colors.tabUnselected.opacity(OnboardingDemoChromeLayout.strokeOpacity),
            lineWidth: 1
          )
      }
      .shadow(color: .black.opacity(0.14), radius: 14, y: 6)
  }
}
