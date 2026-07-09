import SwiftUI

/// Animated marketing slide in the logged-out onboarding carousel.
struct LoggedOutOnboardingFeatureSlideView: View {
    let page: AppLoggedOutOnboardingPresentation.FeaturePage
    let isActive: Bool

    @State private var hasAnimatedIn = false

    private var demoMaxHeight: CGFloat {
        LoggedOutOnboardingFeatureSlidePresentation.demoMaxHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: AppTheme.Spacing.sm)

            featureVisual
                .frame(maxWidth: .infinity)

            Spacer(minLength: LoggedOutOnboardingFeatureSlidePresentation.copyTopSpacing)

            featureCopyBlock
                .padding(.horizontal, AppTheme.Spacing.lg)
                .offset(y: hasAnimatedIn ? 0 : 20)
                .opacity(hasAnimatedIn ? 1 : 0)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(page.accessibilityIdentifier)

            Spacer(minLength: LoggedOutOnboardingFeatureSlidePresentation.copyBottomSpacing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: isActive) { _, active in
            guard active else {
                hasAnimatedIn = false
                return
            }
            animateIn()
        }
        .onAppear {
            if isActive {
                animateIn()
            }
        }
    }

    @ViewBuilder
    private var featureVisual: some View {
        if page.kind == .logEveryDive {
            OnboardingLogEveryDiveDemoView(
                isActive: isActive && hasAnimatedIn,
                maxPhoneHeight: demoMaxHeight
            )
            .scaleEffect(hasAnimatedIn ? 1 : 0.94)
            .opacity(hasAnimatedIn ? 1 : 0)
        } else if page.kind == .exploreSites {
            OnboardingExploreSitesDemoView(
                isActive: isActive && hasAnimatedIn,
                maxPhoneHeight: demoMaxHeight
            )
            .scaleEffect(hasAnimatedIn ? 1 : 0.94)
            .opacity(hasAnimatedIn ? 1 : 0)
        } else if page.kind == .shareWithFriends {
            OnboardingShareWithFriendsDemoView(
                isActive: isActive && hasAnimatedIn,
                maxPhoneHeight: demoMaxHeight
            )
            .scaleEffect(hasAnimatedIn ? 1 : 0.94)
            .opacity(hasAnimatedIn ? 1 : 0)
        } else if page.kind == .monitorEquipment {
            OnboardingMonitorEquipmentDemoView(
                isActive: isActive && hasAnimatedIn,
                maxPhoneHeight: demoMaxHeight
            )
            .scaleEffect(hasAnimatedIn ? 1 : 0.94)
            .opacity(hasAnimatedIn ? 1 : 0)
        } else if page.kind == .marineSpecies {
            OnboardingMarineSpeciesDemoView(
                isActive: isActive && hasAnimatedIn,
                maxPhoneHeight: demoMaxHeight
            )
            .scaleEffect(hasAnimatedIn ? 1 : 0.94)
            .opacity(hasAnimatedIn ? 1 : 0)
        } else {
            marketingSymbolCluster
        }
    }

    private var featureCopyBlock: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text(page.title)
                .font(.title.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(LoggedOutOnboardingFeatureSlidePresentation.titleLineLimit)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.9)
                .allowsTightening(true)

            Text(page.body)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func animateIn() {
        hasAnimatedIn = false
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
            hasAnimatedIn = true
        }
    }

    private var marketingSymbolCluster: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppTheme.Colors.accentDeep.opacity(0.28),
                            AppTheme.Colors.accent.opacity(0.08),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 88
                    )
                )
                .frame(width: 176, height: 176)
                .scaleEffect(hasAnimatedIn ? 1 : 0.6)
                .opacity(hasAnimatedIn ? 1 : 0)

            Image(systemName: page.systemImage)
                .font(.system(size: 58, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.accentDeep)
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.pulse.wholeSymbol, options: .repeating.speed(0.55), isActive: isActive && hasAnimatedIn)
                .scaleEffect(hasAnimatedIn ? 1 : 0.5)
                .opacity(hasAnimatedIn ? 1 : 0)
                .accessibilityHidden(true)

            if let accentSymbolName = page.accentSymbolName {
                Image(systemName: accentSymbolName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.accent)
                    .offset(x: 52, y: -44)
                    .scaleEffect(hasAnimatedIn ? 1 : 0.2)
                    .opacity(hasAnimatedIn ? 0.95 : 0)
                    .symbolEffect(.bounce, value: hasAnimatedIn)
                    .accessibilityHidden(true)
            }
        }
    }
}
