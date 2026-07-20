import SwiftData
import SwiftUI

private enum LoggedOutOnboardingPhase: Equatable {
    case welcome
    case features
}

/// Logged-out onboarding — welcome activity picker, conditional feature slides, then Sign in with Apple.
struct LoggedOutOnboardingView: View {
    @State private var phase: LoggedOutOnboardingPhase = .welcome
    @State private var showsDedicatedSignIn = false
    @State private var activitySelection = UserOnboardingActivitySelection.welcomeDefault
    @State private var featurePageIndex = 0
    @State private var featurePages: [AppLoggedOutOnboardingPresentation.FeaturePage] = []

    private var featurePageCount: Int { featurePages.count }

    private enum CarouselTransition {
        static let featurePage = Animation.easeInOut(duration: 0.28)
    }

    var body: some View {
        Group {
            if showsDedicatedSignIn {
                SignInView(onBack: dismissDedicatedSignIn)
            } else {
                onboardingContent
            }
        }
        .accessibilityIdentifier(AppLoggedOutOnboardingPresentation.rootAccessibilityIdentifier)
    }

    private var onboardingContent: some View {
        LoggedOutMarketingChrome {
            VStack(spacing: 0) {
                if phase != .welcome {
                    topBar
                }

                Group {
                    switch phase {
                    case .welcome:
                        LoggedOutOnboardingWelcomeView(
                            selection: $activitySelection,
                            onContinue: beginFeatureTour,
                            onSignIn: showDedicatedSignInFromWelcome
                        )
                    case .features:
                        featureCarousel
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if phase == .features {
                    bottomChrome
                }
            }
        }
    }

    private var featureCarousel: some View {
        TabView(selection: $featurePageIndex) {
            ForEach(Array(featurePages.enumerated()), id: \.element.id) { index, page in
                LoggedOutOnboardingFeatureSlideView(
                    page: page,
                    isActive: featurePageIndex == index
                )
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(CarouselTransition.featurePage, value: featurePageIndex)
    }

    private var topBar: some View {
        HStack {
            if phase == .features,
               AppLoggedOutOnboardingPresentation.showsFeatureBackButton(
                featurePageCount: featurePageCount
               ) {
                Button {
                    handleFeatureBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .accessibilityLabel("Back")
                .accessibilityIdentifier("LoggedOutOnboarding.Back")
            }

            Spacer(minLength: 0)

            if AppLoggedOutOnboardingPresentation.showsSkipButton(
                featurePageIndex: featurePageIndex,
                featurePageCount: featurePageCount
            ) {
                Button(AppLoggedOutOnboardingPresentation.skipButtonTitle) {
                    showDedicatedSignIn()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .accessibilityIdentifier("LoggedOutOnboarding.Skip")
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, AppTheme.Spacing.md)
        .padding(.bottom, AppTheme.Spacing.sm)
    }

    private var bottomChrome: some View {
        VStack(spacing: LoggedOutOnboardingFeatureSlidePresentation.bottomChromeStackSpacing) {
            if featurePageCount > 0 {
                if AppLoggedOutOnboardingPresentation.showsContinueButton(
                    featurePageIndex: featurePageIndex,
                    featurePageCount: featurePageCount
                ) {
                    Button(AppLoggedOutOnboardingPresentation.continueButtonTitle) {
                        featurePageIndex += 1
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("LoggedOutOnboarding.Continue")
                } else if AppLoggedOutOnboardingPresentation.showsSignInWithAppleOnLastFeatureSlide(
                    featurePageIndex: featurePageIndex,
                    featurePageCount: featurePageCount
                ) {
                    SignInWithAppleSection(
                        buttonAccessibilityIdentifier: "LoggedOutOnboarding.LastSlide.AppleButton"
                    )
                }

                pageIndicator
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, LoggedOutOnboardingFeatureSlidePresentation.bottomChromeTopPadding)
        .padding(.bottom, LoggedOutOnboardingFeatureSlidePresentation.bottomChromeBottomPadding)
        // Sit just above the home indicator instead of above the full bottom safe area.
        .ignoresSafeArea(edges: .bottom)
    }

    private var pageIndicator: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ForEach(0..<featurePageCount, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(
                        index == featurePageIndex
                            ? AppTheme.Colors.accentDeep
                            : AppTheme.Colors.tabUnselected.opacity(0.35)
                    )
                    .frame(width: index == featurePageIndex ? 20 : 8, height: 8)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(featurePageIndex + 1) of \(featurePageCount)")
        .accessibilityIdentifier("LoggedOutOnboarding.PageIndicator")
    }

    private func beginFeatureTour() {
        UserOnboardingActivitySelection.savePending(activitySelection)
        featurePages = AppLoggedOutOnboardingPresentation.featurePages(for: activitySelection)
        featurePageIndex = 0
        if featurePages.isEmpty {
            showDedicatedSignIn()
        } else {
            phase = .features
        }
    }

    private func handleFeatureBack() {
        if AppLoggedOutOnboardingPresentation.featureBackReturnsToWelcome(
            featurePageIndex: featurePageIndex
        ) {
            returnToWelcomeFromFeatures()
        } else {
            featurePageIndex -= 1
        }
    }

    private func returnToWelcomeFromFeatures() {
        UserOnboardingActivitySelection.clearPending()
        featurePageIndex = 0
        featurePages = []
        phase = .welcome
    }

    private func showDedicatedSignInFromWelcome() {
        // Do not treat welcome picks as committed — Sign in path may still be a brand-new account
        // and should run post–SIWA interests → photo → permissions → import.
        UserOnboardingActivitySelection.clearPending()
        showDedicatedSignIn()
    }

    private func showDedicatedSignIn() {
        showsDedicatedSignIn = true
    }

    private func dismissDedicatedSignIn() {
        showsDedicatedSignIn = false
    }
}

#Preview {
    LoggedOutOnboardingView()
        .environment(AccountSession.shared)
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
