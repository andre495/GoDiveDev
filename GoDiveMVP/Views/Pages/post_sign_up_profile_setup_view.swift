import PhotosUI
import SwiftData
import SwiftUI

/// Brand-new account wizard — profile photo, optional DAN + certification, preview, then celebration.
struct PostSignUpProfileSetupView: View {
    @Environment(AccountSession.self) private var accountSession
    @Environment(\.modelContext) private var modelContext

    let onComplete: () -> Void

    @Query(sort: [SortDescriptor(\Certification.dateAttained, order: .reverse)])
    private var allCertifications: [Certification]

    @State private var stepIndex = 0
    @State private var danText = ""
    @State private var certificationForm = CertificationFormValues()
    @State private var frontPhotoPickerItem: PhotosPickerItem?
    @State private var backPhotoPickerItem: PhotosPickerItem?
    @State private var saveErrorMessage: String?

    private var profile: UserProfile? { accountSession.currentProfile }

    private var steps: [PostSignUpProfileSetupPresentation.Step] {
        guard let profile else { return [] }
        return PostSignUpProfileSetupPresentation.steps(for: profile)
    }

    private var currentStep: PostSignUpProfileSetupPresentation.Step? {
        guard steps.indices.contains(stepIndex) else { return nil }
        return steps[stepIndex]
    }

    private var ownedCertifications: [Certification] {
        guard let ownerID = profile?.id else { return [] }
        return allCertifications.filter { $0.ownerProfileID == ownerID }
    }

    var body: some View {
        LoggedOutMarketingChrome {
            VStack(spacing: AppTheme.Spacing.lg) {
                navigationChrome

                Group {
                    if let currentStep, let profile {
                        stepContent(currentStep, profile: profile)
                            .id(currentStep)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.28), value: stepIndex)

                bottomChrome
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.bottom, AppTheme.Spacing.lg)
            }
        }
        .accessibilityIdentifier(PostSignUpProfileSetupPresentation.rootAccessibilityIdentifier)
        .alert("Could not save", isPresented: saveErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "Try again.")
        }
        .onAppear {
            if let dan = profile?.danInsuranceNumber {
                danText = dan
            }
        }
    }

    @ViewBuilder
    private var navigationChrome: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            if PostSignUpProfileSetupPresentation.showsBackButton(stepIndex: stepIndex) {
                topBar
            }

            progressHeader
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, PostSignUpProfileSetupPresentation.showsBackButton(stepIndex: stepIndex) ? 0 : AppTheme.Spacing.md)
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                goBackOneStep()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .accessibilityLabel("Back")
            .accessibilityIdentifier(PostSignUpProfileSetupPresentation.backButtonAccessibilityIdentifier)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, AppTheme.Spacing.md)
    }

    @ViewBuilder
    private var progressHeader: some View {
        if steps.count > 1 {
            HStack(spacing: AppTheme.Spacing.sm) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, _ in
                    Capsule()
                        .fill(
                            index <= stepIndex
                                ? AppTheme.Colors.accentDeep
                                : AppTheme.Colors.surfaceMuted.opacity(0.55)
                        )
                        .frame(height: 4)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(stepIndex + 1) of \(steps.count)")
        }
    }

    @ViewBuilder
    private func stepContent(
        _ step: PostSignUpProfileSetupPresentation.Step,
        profile: UserProfile
    ) -> some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            stepHeader(step, displayName: profile.displayName)

            switch step {
            case .certification:
                certificationStep
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            default:
                ScrollView {
                    stepBody(step, profile: profile)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.vertical, AppTheme.Spacing.md)
        .accessibilityIdentifier(PostSignUpProfileSetupPresentation.stepAccessibilityIdentifier(step))
    }

    private func stepHeader(
        _ step: PostSignUpProfileSetupPresentation.Step,
        displayName: String
    ) -> some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Text(PostSignUpProfileSetupPresentation.stepTitle(step, displayName: displayName))
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text(PostSignUpProfileSetupPresentation.stepSubtitle(step))
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
    }

    @ViewBuilder
    private func stepBody(
        _ step: PostSignUpProfileSetupPresentation.Step,
        profile: UserProfile
    ) -> some View {
        switch step {
        case .profilePhoto:
            profilePhotoStep(profile: profile)
        case .danInsurance:
            danInsuranceStep
        case .certification:
            EmptyView()
        case .preview:
            profilePreviewStep(profile: profile)
        }
    }

    private func profilePhotoStep(profile: UserProfile) -> some View {
        ProfileAvatarEditor(diameter: 148, profile: profile)
            .frame(maxWidth: .infinity)
            .padding(.top, AppTheme.Spacing.md)
    }

    private var danInsuranceStep: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Diver Medical Insurance (DAN)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            TextField("DAN member number", text: $danText)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.Colors.surfaceMuted.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityIdentifier("PostSignUpProfileSetup.DanField")
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
    }

    private var certificationStep: some View {
        Form {
            CertificationFormContent(
                form: $certificationForm,
                frontPhotoPickerItem: $frontPhotoPickerItem,
                backPhotoPickerItem: $backPhotoPickerItem
            )
        }
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func profilePreviewStep(profile: UserProfile) -> some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            ProfileAvatarView(
                profilePhoto: profile.profilePhoto,
                diameter: 148,
                iconFont: .system(size: 70)
            )
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)

            VStack(spacing: AppTheme.Spacing.sm) {
                Text(profile.displayName)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                if let dan = profile.danInsuranceNumber, !dan.isEmpty {
                    Text(ProfilePresentation.danInsuranceLabel(dan))
                        .font(.body.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .accessibilityIdentifier("PostSignUpProfileSetup.Preview.Dan")
                }

                profilePreviewCertificationSummary

                interestChips(for: profile)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("PostSignUpProfileSetup.Preview.Card")
    }

    @ViewBuilder
    private var profilePreviewCertificationSummary: some View {
        if let display = CertificationPresentation.profileFeaturedCertification(from: ownedCertifications) {
            VStack(spacing: AppTheme.Spacing.sm) {
                Text(display.title)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.tabSelected)
                    .multilineTextAlignment(.center)

                if let certNumber = display.certNumber {
                    Text(certNumber)
                        .font(.body.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.tabSelected)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("PostSignUpProfileSetup.Preview.CertNumber")
                }
            }
        }
    }

    private func interestChips(for profile: UserProfile) -> some View {
        let kinds = PostSignUpProfileSetupPresentation.selectedInterestKinds(for: profile)
        return VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Interests")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            FlowLayout(spacing: AppTheme.Spacing.sm) {
                ForEach(kinds) { kind in
                    interestChip(for: kind)
                }
            }
        }
        .padding(.top, AppTheme.Spacing.sm)
        .accessibilityIdentifier("PostSignUpProfileSetup.Preview.Interests")
    }

    private func interestChip(for kind: UserOnboardingActivityKind) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            interestChipIcon(for: kind)
            Text(kind.title)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(AppTheme.Colors.accentDeep)
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(AppTheme.Colors.accentLight.opacity(0.45))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private func interestChipIcon(for kind: UserOnboardingActivityKind) -> some View {
        if let assetName = kind.assetImageName {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
        } else if let systemImage = kind.systemImage {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
        }
    }

    @ViewBuilder
    private var bottomChrome: some View {
        if let currentStep {
            VStack(spacing: AppTheme.Spacing.sm) {
                if showsContinueButton(for: currentStep) {
                    Button(PostSignUpProfileSetupPresentation.continueTitle(for: currentStep)) {
                        advanceFromCurrentStep()
                    }
                    .appOnboardingPrimaryGlassButtonStyle()
                    .accessibilityIdentifier("PostSignUpProfileSetup.Continue")
                }

                if let skipTitle = PostSignUpProfileSetupPresentation.skipTitle(for: currentStep) {
                    Button(skipTitle) {
                        skipCurrentStep()
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .accessibilityIdentifier("PostSignUpProfileSetup.Skip")
                }
            }
        }
    }

    private func showsContinueButton(
        for step: PostSignUpProfileSetupPresentation.Step
    ) -> Bool {
        PostSignUpProfileSetupPresentation.showsContinueButton(
            for: step,
            hasProfilePhoto: profile?.profilePhoto != nil,
            danInsuranceNumber: danText,
            certificationFormCanSave: certificationForm.canSave
        )
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )
    }

    private func advanceFromCurrentStep() {
        guard let currentStep else { return }

        switch currentStep {
        case .danInsurance:
            saveDanInsurance()
        case .certification:
            guard saveCertification() else { return }
        case .profilePhoto, .preview:
            break
        }

        if stepIndex >= steps.count - 1 {
            onComplete()
        } else {
            stepIndex += 1
        }
    }

    private func skipCurrentStep() {
        guard stepIndex < steps.count - 1 else {
            onComplete()
            return
        }
        stepIndex += 1
    }

    private func goBackOneStep() {
        guard PostSignUpProfileSetupPresentation.showsBackButton(stepIndex: stepIndex) else { return }
        withAnimation(.easeInOut(duration: 0.28)) {
            stepIndex -= 1
        }
    }

    private func saveDanInsurance() {
        guard let profile else { return }
        profile.danInsuranceNumber = UserProfileStore.sanitizedDanInsuranceNumber(danText)
        do {
            try modelContext.save()
        } catch {
            saveErrorMessage = "Could not save DAN number. Try again."
        }
    }

    @discardableResult
    private func saveCertification() -> Bool {
        guard certificationForm.canSave else { return true }
        guard let profile else {
            saveErrorMessage = "Sign in to save a certification."
            return false
        }

        let certification = certificationForm.makeCertification()
        CertificationOwnership.assignOwner(profile, to: certification)
        modelContext.insert(certification)

        do {
            try modelContext.save()
            certificationForm = CertificationFormValues()
            frontPhotoPickerItem = nil
            backPhotoPickerItem = nil
            return true
        } catch {
            saveErrorMessage = error.localizedDescription
            return false
        }
    }
}

/// Simple left-to-right wrapping layout for interest chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    PostSignUpProfileSetupView(onComplete: {})
        .environment(AccountSession.shared)
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
