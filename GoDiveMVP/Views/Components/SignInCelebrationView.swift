import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Full-screen GoDive brand + rising bubble ramp after profile setup — then Home slides up.
struct SignInCelebrationView: View {
    let onComplete: () -> Void

    @State private var logoScale: CGFloat = 0.72
    @State private var logoOpacity: CGFloat = 0
    @State private var brandOpacity: CGFloat = 0
    @State private var bubbleSpeedMultiplier = SignInCelebrationPresentation.bubbleSpeedStartMultiplier
    @State private var dismissTask: Task<Void, Never>?
    @State private var hapticTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            WaterBubbleBackground(
                intensity: .standard,
                speedMultiplier: bubbleSpeedMultiplier
            )

            AppTheme.Colors.surface
                .opacity(0.28)
                .ignoresSafeArea()

            VStack(spacing: AppTheme.Spacing.lg) {
                Image("GoDiveLogoPin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 128, height: 128)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .shadow(color: AppTheme.Colors.accentDeep.opacity(0.35), radius: 24, y: 8)
                    .accessibilityIdentifier(SignInCelebrationPresentation.logoAccessibilityIdentifier)

                GoDiveBrandWordmarkText()
                    .opacity(brandOpacity)
                    .accessibilityIdentifier(SignInCelebrationPresentation.brandAccessibilityIdentifier)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("GoDive")
        }
        .ignoresSafeArea()
        .accessibilityIdentifier(SignInCelebrationPresentation.rootAccessibilityIdentifier)
        .onAppear {
            withAnimation(
                .spring(
                    response: SignInCelebrationPresentation.logoSpringResponse,
                    dampingFraction: SignInCelebrationPresentation.logoSpringDamping
                )
            ) {
                logoScale = 1
                logoOpacity = 1
            }
            withAnimation(
                .easeOut(duration: SignInCelebrationPresentation.brandFadeDuration)
                    .delay(SignInCelebrationPresentation.brandFadeDelay)
            ) {
                brandOpacity = 1
            }
            withAnimation(.easeIn(duration: SignInCelebrationPresentation.bubbleSpeedRampDuration)) {
                bubbleSpeedMultiplier = SignInCelebrationPresentation.bubbleSpeedEndMultiplier
            }

            startCelebrationHapticsIfNeeded()

            dismissTask?.cancel()
            dismissTask = Task {
                try? await Task.sleep(nanoseconds: SignInCelebrationPresentation.durationNanoseconds)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    onComplete()
                }
            }
        }
        .onDisappear {
            dismissTask?.cancel()
            dismissTask = nil
            hapticTask?.cancel()
            hapticTask = nil
        }
    }

    private func startCelebrationHapticsIfNeeded() {
        hapticTask?.cancel()
        guard SignInCelebrationPresentation.shouldPlayCelebrationHaptics() else { return }

        hapticTask = Task { @MainActor in
            let startDelay = SignInCelebrationPresentation.hapticBurstStartDelaySeconds
            try? await Task.sleep(nanoseconds: UInt64(startDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }

            #if canImport(UIKit)
            let light = UIImpactFeedbackGenerator(style: .light)
            let soft = UIImpactFeedbackGenerator(style: .soft)
            let medium = UIImpactFeedbackGenerator(style: .medium)
            light.prepare()
            soft.prepare()
            medium.prepare()

            for index in 0 ..< SignInCelebrationPresentation.hapticBurstCount {
                guard !Task.isCancelled else { return }
                let generator: UIImpactFeedbackGenerator
                switch index % 3 {
                case 0: generator = light
                case 1: generator = soft
                default: generator = medium
                }
                generator.impactOccurred(intensity: index.isMultiple(of: 4) ? 0.85 : 0.55)
                generator.prepare()

                let interval = SignInCelebrationPresentation.hapticIntervalSeconds(index: index)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
            #endif
        }
    }
}

#Preview {
    SignInCelebrationView(onComplete: {})
}
