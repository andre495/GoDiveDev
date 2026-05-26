import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppUserSettings.automaticallyRenumberDivesKey) private var automaticallyRenumberDives = false
    @AppStorage(AppUserSettings.useImperialDisplayUnitsKey) private var useImperialDisplayUnits = false
    @AppStorage(AppUserSettings.defaultTankSizeKey) private var defaultTankSizeRaw = DefaultTankSize.al80.rawValue

    var body: some View {
        AppPage(title: "Settings", showsBackButton: true) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                SettingsToggleRow(
                    title: SettingsPresentation.ImperialUnits.title,
                    infoMessage: SettingsPresentation.ImperialUnits.infoMessage,
                    isOn: $useImperialDisplayUnits
                )

                SettingsPickerRow(
                    title: SettingsPresentation.DefaultTank.title,
                    infoMessage: SettingsPresentation.DefaultTank.infoMessage,
                    selection: Binding(
                        get: { DefaultTankSize(rawValue: defaultTankSizeRaw) ?? .al80 },
                        set: { defaultTankSizeRaw = $0.rawValue }
                    ),
                    options: DefaultTankSize.allCases.map { (tag: $0, label: $0.settingsPickerTitle) }
                )

                SettingsToggleRow(
                    title: SettingsPresentation.AutomaticallyRenumberDives.title,
                    infoMessage: SettingsPresentation.AutomaticallyRenumberDives.infoMessage,
                    isOn: $automaticallyRenumberDives
                )
                .onChange(of: automaticallyRenumberDives) { _, isOn in
                    guard isOn else { return }
                    Task { @MainActor in
                        try? DiveActivityDiveNumbering.renumberAllChronologically(modelContext: modelContext)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.top, AppTheme.Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .hidesBottomTabBarWhenPushed()
    }
}

#Preview {
    SettingsView()
        .modelContainer(
            for: [
                DiveActivity.self,
                DiveBuddyTag.self,
                DiveProfilePoint.self,
                DiveSite.self,
            ],
            inMemory: true
        )
}
