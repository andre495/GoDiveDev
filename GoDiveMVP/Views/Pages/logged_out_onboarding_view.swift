import SwiftData
import SwiftUI

private enum LoggedOutOnboardingPhase: Equatable {
    case welcome
    case features
    case signUp
}

/// Logged-out onboarding — welcome activity picker, conditional feature slides, sign-up.
struct LoggedOutOnboardingView: View {
    @State private var phase: LoggedOutOnboardingPhase = .welcome
    @State private var activitySelection = UserOnboardingActivitySelection.welcomeDefault
    @State private var featurePageIndex = 0
    @State private var featurePages: [AppLoggedOutOnboardingPresentation.FeaturePage] = []

    private var featurePageCount: Int { featurePages.count }

    private var showsSignUp: Bool {
        phase == .signUp
    }

    private enum CarouselTransition {
        static let signUpSlide = Animation.spring(response: 0.44, dampingFraction: 0.9)
        static let featurePage = Animation.easeInOut(duration: 0.28)
    }

    var body: some View {
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
                            onSignIn: jumpToSignUpFromWelcome
                        )
                    case .features, .signUp:
                        carouselBody
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if phase == .features || phase == .signUp {
                    bottomChrome
                }
            }
        }
        .accessibilityIdentifier(AppLoggedOutOnboardingPresentation.rootAccessibilityIdentifier)
    }

    @ViewBuilder
    private var carouselBody: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                featureCarousel
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .allowsHitTesting(phase == .features)

                signUpPage
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .offset(y: showsSignUp ? 0 : geometry.size.height)
            }
            .clipped()
            .animation(CarouselTransition.signUpSlide, value: phase)
        }
    }

    private var featureCarousel: some View {
        TabView(selection: $featurePageIndex) {
            ForEach(Array(featurePages.enumerated()), id: \.element.id) { index, page in
                LoggedOutOnboardingFeatureSlideView(
                    page: page,
                    isActive: phase == .features && featurePageIndex == index
                )
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(CarouselTransition.featurePage, value: featurePageIndex)
    }

    private var topBar: some View {
        HStack {
            if phase == .features, featurePageIndex > 0 {
                Button {
                    featurePageIndex -= 1
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .accessibilityLabel("Back")
                .accessibilityIdentifier("LoggedOutOnboarding.Back")
            }

            Spacer(minLength: 0)

            if !showsSignUp {
                Button(AppLoggedOutOnboardingPresentation.skipButtonTitle) {
                    jumpToSignUp()
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

    private var signUpPage: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer(minLength: AppTheme.Spacing.lg)

            VStack(spacing: AppTheme.Spacing.lg) {
                Image("GoDiveLogoPin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 112, height: 112)
                    .accessibilityHidden(true)
                    .accessibilityIdentifier("LoggedOutOnboarding.SignUp.Logo")

                VStack(spacing: AppTheme.Spacing.sm) {
                    Text(AppLoggedOutOnboardingPresentation.signUpTitle)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(AppLoggedOutOnboardingPresentation.signUpSubtitle)
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("LoggedOutOnboarding.SignUp.Copy")
            }

            SignInWithAppleSection(
                buttonAccessibilityIdentifier: "LoggedOutOnboarding.SignUp.AppleButton"
            )
            .padding(.horizontal, AppTheme.Spacing.lg)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("LoggedOutOnboarding.SignUp")
    }

    private var bottomChrome: some View {
        VStack(spacing: LoggedOutOnboardingFeatureSlidePresentation.bottomChromeStackSpacing) {
            if phase == .features, featurePageCount > 0 {
                pageIndicator

                let continueTitle = AppLoggedOutOnboardingPresentation.continueButtonTitle(
                    featurePageIndex: featurePageIndex,
                    featurePageCount: featurePageCount
                )
                let showsGetStartedCallout = continueTitle == AppLoggedOutOnboardingPresentation.getStartedButtonTitle

                Button(continueTitle) {
                    advanceFromFeaturePage()
                }
                .font(showsGetStartedCallout ? .title3.weight(.bold) : .body.weight(.semibold))
                .foregroundStyle(
                    showsGetStartedCallout
                        ? AppTheme.Colors.accentDeep
                        : AppTheme.Colors.secondaryText
                )
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .modifier(LoggedOutOnboardingGetStartedCalloutModifier(isActive: showsGetStartedCallout))
                .accessibilityIdentifier("LoggedOutOnboarding.Continue")
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
            jumpToSignUp()
        } else {
            phase = .features
        }
    }

    private func jumpToSignUpFromWelcome() {
        UserOnboardingActivitySelection.savePending(activitySelection)
        featurePages = AppLoggedOutOnboardingPresentation.featurePages(for: activitySelection)
        jumpToSignUp()
    }

    private func advanceFromFeaturePage() {
        let lastFeatureIndex = max(featurePageCount - 1, 0)
        if featurePageIndex < lastFeatureIndex {
            featurePageIndex += 1
        } else {
            jumpToSignUp()
        }
    }

    private func jumpToSignUp() {
        withAnimation(CarouselTransition.signUpSlide) {
            phase = .signUp
        }
    }
}

/// Strong scale + opacity pulse on the last feature slide’s **Get started** control (twice, then static).
private struct LoggedOutOnboardingGetStartedCalloutModifier: ViewModifier {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var calloutScale: CGFloat = 1
    @State private var calloutOpacity: Double = 1
    @State private var calloutTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .scaleEffect(calloutScale)
            .opacity(calloutOpacity)
            .onChange(of: isActive) { _, active in
                restartCalloutIfNeeded(active: active)
            }
            .onAppear {
                restartCalloutIfNeeded(active: isActive)
            }
            .onDisappear {
                calloutTask?.cancel()
                calloutTask = nil
            }
    }

    private func restartCalloutIfNeeded(active: Bool) {
        calloutTask?.cancel()
        calloutTask = nil
        calloutScale = 1
        calloutOpacity = 1

        guard active, !reduceMotion else { return }

        let peak = LoggedOutOnboardingFeatureSlidePresentation.getStartedCalloutPeakScale
        let dimmed = LoggedOutOnboardingFeatureSlidePresentation.getStartedCalloutMinOpacity
        let halfCycle = LoggedOutOnboardingFeatureSlidePresentation.getStartedCalloutCycleSeconds
        let pulseCount = LoggedOutOnboardingFeatureSlidePresentation.getStartedCalloutPulseCount
        let halfCycleNanos = UInt64(halfCycle * 1_000_000_000)

        calloutTask = Task { @MainActor in
            for _ in 0 ..< pulseCount {
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: halfCycle)) {
                    calloutScale = peak
                    calloutOpacity = dimmed
                }
                try? await Task.sleep(nanoseconds: halfCycleNanos)
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: halfCycle)) {
                    calloutScale = 1
                    calloutOpacity = 1
                }
                try? await Task.sleep(nanoseconds: halfCycleNanos)
            }
        }
    }
}

#Preview {
    LoggedOutOnboardingView()
        .environment(AccountSession.shared)
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
