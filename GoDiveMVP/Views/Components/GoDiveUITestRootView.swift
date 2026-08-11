import SwiftUI

/// Stable root for UI tests: no SwiftData, MapKit, canvas animations, or post-launch view swaps
/// (swapping roots drops the accessibility server and causes **`kAXErrorServerNotFound`**).
struct GoDiveUITestRootView: View {
    @State private var showsAddDiveSiteSheet = false

    var body: some View {
        TabView {
            uiTestHomeTab
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            uiTestPlaceholderTab(title: "Logbook")
                .tabItem {
                    Label("Logbook", systemImage: "book.closed")
                }

            uiTestPlaceholderTab(title: "Field Guide")
                .tabItem {
                    Label("Field Guide", systemImage: "leaf")
                }

            uiTestExploreTab
                .tabItem {
                    Label("Explore", systemImage: "map")
                }
        }
        .accessibilityIdentifier("GoDive.UITest.Root")
        .tint(AppTheme.Colors.tabSelected)
        .sheet(isPresented: $showsAddDiveSiteSheet) {
            GoDiveUITestDiveSiteAddSheetHarness()
        }
    }

    private var uiTestHomeTab: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                AppTheme.Colors.screenBackgroundGradient
                    .ignoresSafeArea()

                AppHeader(title: "Home", showsBackButton: false, statusBarSafeAreaTop: proxy.safeAreaInsets.top) {
                    Button(action: {}) {
                        Image(systemName: "person.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Profile")
                }
            }
        }
    }

    /// Explore placeholder plus the production add-site chrome id so sheet presentation can be UI-tested
    /// without mounting SwiftData / MapKit Explore.
    private var uiTestExploreTab: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text("Explore")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabUnselected)
                .accessibilityLabel("Explore")

            Button {
                showsAddDiveSiteSheet = true
            } label: {
                Image(systemName: ExploreDiveSiteAddPresentation.chromeSystemImage)
                    .appToolbarIconButtonLabel()
            }
            .appStandaloneIconButtonStyle()
            .accessibilityLabel(ExploreDiveSiteAddPresentation.chromeAccessibilityLabel)
            .accessibilityIdentifier(ExploreDiveSiteAddPresentation.chromeAccessibilityIdentifier)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.screenBackgroundGradient)
    }

    private func uiTestPlaceholderTab(title: String) -> some View {
        Text(title)
            .font(.title2.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.tabUnselected)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.Colors.screenBackgroundGradient)
            .accessibilityLabel(title)
    }
}

/// SwiftData-free add-site sheet that mirrors production host-root country picker presentation.
private struct GoDiveUITestDiveSiteAddSheetHarness: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft = DiveSiteFormDraft(
        siteName: "",
        country: "",
        region: "",
        bodyOfWater: "",
        latitudeText: "",
        longitudeText: ""
    )
    @State private var showsCountryPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("Open country picker") {
                        showsCountryPicker = true
                    }
                    .accessibilityIdentifier("DiveSiteForm.CountryPicker.UITestOpen")
                }

                DiveSiteFormContent(
                    draft: $draft,
                    fallbackCoordinate: nil,
                    clearsListRowBackgrounds: true,
                    showsCountryPicker: $showsCountryPicker
                )
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppGlassToolbarCancelButton(
                        action: { dismiss() },
                        accessibilityIdentifier: ExploreDiveSiteAddPresentation.cancelAccessibilityIdentifier
                    )
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppGlassProminentDoneButton(
                        action: { dismiss() },
                        accessibilityIdentifier: ExploreDiveSiteAddPresentation.doneAccessibilityIdentifier,
                        isEnabled: true
                    )
                }
            }
        }
        .diveSiteAddSheetPresentation()
        .sheet(isPresented: $showsCountryPicker) {
            DiveSiteCountryPickerSheet(selectedCountry: $draft.country)
        }
        .accessibilityIdentifier("Explore.AddDiveSiteSheet.Root")
    }
}
