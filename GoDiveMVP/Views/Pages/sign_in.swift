import SwiftData
import SwiftUI

struct SignInView: View {
    /// When set (onboarding → dedicated sign-in), shows a leading back control to return to welcome / feature slides.
    var onBack: (() -> Void)? = nil

    @Environment(AccountSession.self) private var accountSession
    @Environment(\.modelContext) private var modelContext
    @State private var showsCrashReports = false
    @State private var savedCrashReportCount = 0

    var body: some View {
        LoggedOutMarketingChrome {
            VStack(spacing: AppTheme.Spacing.lg) {
                if onBack != nil {
                    backBar
                }

                Spacer(minLength: AppTheme.Spacing.lg)

                VStack(spacing: AppTheme.Spacing.md) {
                    VStack(spacing: AppTheme.Spacing.lg) {
                        GoDiveLogoPinPresentation.image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 128, height: 128)
                            .accessibilityHidden(true)
                            .accessibilityIdentifier("SignIn.Logo")

                        Text("GoDive")
                            .font(AppTheme.Typography.headerBrandTitle.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }

                    Text("Log every dive. Explore marine life. Connect with buddies.")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppTheme.Spacing.lg)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "GoDive. Log every dive. Explore marine life. Connect with buddies."
                )

                SignInWithAppleSection()
                    .padding(.horizontal, AppTheme.Spacing.lg)

                if savedCrashReportCount > 0 {
                    Button(SignInPresentation.loggedOutCrashReportsLinkTitle) {
                        showsCrashReports = true
                    }
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
                    .accessibilityIdentifier(SignInPresentation.loggedOutCrashReportsAccessibilityIdentifier)
                }

                Spacer()
            }
        }
        .accessibilityIdentifier("SignIn.Root")
        .task { refreshSavedCrashReportCount() }
        .sheet(isPresented: $showsCrashReports) {
            NavigationStack {
                CrashReportsView()
            }
        }
    }

    private func refreshSavedCrashReportCount() {
        savedCrashReportCount = CrashReportStore(container: modelContext.container).loadAll().count
    }

    private var backBar: some View {
        HStack {
            Button {
                onBack?()
            } label: {
                Image(systemName: "chevron.left")
                    .appToolbarIconButtonLabel()
            }
            .appStandaloneIconButtonStyle()
            .accessibilityLabel("Back")
            .accessibilityIdentifier(SignInPresentation.backButtonAccessibilityIdentifier)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, AppTheme.Spacing.md)
    }
}

#Preview {
    SignInView()
        .environment(AccountSession.shared)
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
