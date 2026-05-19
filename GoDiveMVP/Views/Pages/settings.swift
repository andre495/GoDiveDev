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
                Text("Garmin .fit and MacDive / UDDF (.uddf) dives are imported from Logbook using the + button.")
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle(isOn: $useImperialDisplayUnits) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text("Imperial units")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text(
                            "When on, depths show in feet, water temperature in °F, cylinder pressure in psi, and tank volume in cubic feet. Off uses metric (meters, °C, bar, liters). Imported values are always stored the same way; this only changes how numbers appear."
                        )
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(AppTheme.Colors.accent)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Default tank")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(
                        "Used for new imports and gas details when a dive file does not specify cylinder size or material. Existing dives keep their stored values until re-imported."
                    )
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                    Picker("Default tank", selection: $defaultTankSizeRaw) {
                        ForEach(DefaultTankSize.allCases, id: \.rawValue) { size in
                            Text(size.settingsPickerTitle).tag(size.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppTheme.Colors.accent)
                }

                Toggle(isOn: $automaticallyRenumberDives) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text("Automatically renumber dives")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text(
                            "When on, dive numbers stay 1, 2, 3, … in chronological order whenever you import a dive or delete one. When off, numbers are not adjusted after a delete (imports still get the next number in the existing chain). Dives marked with no number (-) in Details are assigned a number when this runs."
                        )
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(AppTheme.Colors.accent)
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
