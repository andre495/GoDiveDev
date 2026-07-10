import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Full-screen GoDive brand + standard bubbles after profile setup — then Home slides up.
struct SignInCelebrationView: View {
    let onComplete: () -> Void

    @State private var logoScale: CGFloat = 0.72
    @State private var logoOpacity: CGFloat = 0
    @State private var brandOpacity: CGFloat = 0
    @State private var celebrationStartTime = Date().timeIntervalSinceReferenceDate
    @State private var dismissTask: Task<Void, Never>?
    @State private var hapticTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            WaterBubbleBackground()

            AppTheme.Colors.surface
                .opacity(0.28)
                .ignoresSafeArea()

            VStack(spacing: AppTheme.Spacing.lg) {
                GoDiveLogoPinPresentation.image
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
        .task {
            let signpostID = SignInCelebrationTransitionDiagnostics.begin(.celebrationFirstFrame)
            celebrationStartTime = Date().timeIntervalSinceReferenceDate
            SignInCelebrationTransitionDiagnostics.mark("SignInCelebrationView_task_begin")
            await Task.yield()
            SignInCelebrationTransitionDiagnostics.mark("SignInCelebrationView_task_after_yield")

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

            startCelebrationHapticsIfNeeded()

            dismissTask?.cancel()
            dismissTask = Task {
                let holdNanoseconds = SignInCelebrationPresentation.durationNanoseconds
                    - SignInCelebrationPresentation.handoffFadeOutNanoseconds
                try? await Task.sleep(nanoseconds: holdNanoseconds)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(.easeOut(duration: SignInCelebrationPresentation.handoffFadeOutDuration)) {
                        logoOpacity = 0
                        brandOpacity = 0
                    }
                }
                try? await Task.sleep(nanoseconds: SignInCelebrationPresentation.handoffFadeOutNanoseconds)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    onComplete()
                }
            }
            SignInCelebrationTransitionDiagnostics.end(.celebrationFirstFrame, signpostID: signpostID)
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

        let startTime = celebrationStartTime
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

            var index = 0
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSinceReferenceDate - startTime
                guard elapsed < SignInCelebrationPresentation.animationDuration else { break }

                let generator: UIImpactFeedbackGenerator
                switch index % 3 {
                case 0: generator = light
                case 1: generator = soft
                default: generator = medium
                }
                generator.impactOccurred(
                    intensity: SignInCelebrationPresentation.hapticImpactIntensity(index: index)
                )
                generator.prepare()

                let interval = SignInCelebrationPresentation.hapticWaitIntervalSeconds(index: index)
                index += 1
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
            #endif
        }
    }
}

#Preview {
    SignInCelebrationView(onComplete: {})
}
