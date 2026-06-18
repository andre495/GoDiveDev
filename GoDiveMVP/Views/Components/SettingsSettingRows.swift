import SwiftUI

/// Compact toggle row — title beside the switch and an **info** affordance for the full description.
struct SettingsToggleRow: View {
    let title: String
    let infoMessage: String
    @Binding var isOn: Bool

    @State private var showsInfo = false

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(AppTheme.Colors.accent)

            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)

            settingsInfoButton
        }
        .alert(title, isPresented: $showsInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(infoMessage)
        }
        .accessibilityElement(children: .combine)
    }

    private var settingsInfoButton: some View {
        Button {
            showsInfo = true
        } label: {
            Image(systemName: "info.circle")
                .font(.body)
                .foregroundStyle(AppTheme.Colors.accent)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(SettingsPresentation.infoAccessibilityLabel(forSettingTitle: title))
    }
}

/// Compact picker row — title on the left, menu on the right, **info** at the trailing edge.
struct SettingsPickerRow<Selection: Hashable>: View {
    let title: String
    let infoMessage: String
    @Binding var selection: Selection
    let options: [(tag: Selection, label: String)]

    @State private var showsInfo = false

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.leading)

            Spacer(minLength: AppTheme.Spacing.sm)

            Picker(title, selection: $selection) {
                ForEach(options, id: \.tag) { option in
                    Text(option.label).tag(option.tag)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(AppTheme.Colors.accent)
            .fixedSize()

            settingsInfoButton
        }
        .alert(title, isPresented: $showsInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(infoMessage)
        }
        .accessibilityElement(children: .contain)
    }

    private var settingsInfoButton: some View {
        Button {
            showsInfo = true
        } label: {
            Image(systemName: "info.circle")
                .font(.body)
                .foregroundStyle(AppTheme.Colors.accent)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(SettingsPresentation.infoAccessibilityLabel(forSettingTitle: title))
    }
}

/// Section title with optional **info** affordance (e.g. **Default Diver Weights**).
struct SettingsSectionHeader: View {
    let title: String
    let infoMessage: String

    @State private var showsInfo = false

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                showsInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.accent)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(SettingsPresentation.infoAccessibilityLabel(forSettingTitle: title))
        }
        .alert(title, isPresented: $showsInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(infoMessage)
        }
    }
}

/// Decimal weight field for **Settings** (canonical **kg** persisted by the parent).
struct SettingsWeightFieldRow: View {
    let title: String
    let unitLabel: String
    @Binding var text: String
    var focused: FocusState<SettingsWeightFieldFocus?>.Binding
    let focusCase: SettingsWeightFieldFocus

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("—", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 88)
                .focused(focused, equals: focusCase)

            Text(unitLabel)
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .frame(minWidth: 28, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

enum SettingsWeightFieldFocus: Hashable {
    case saltWater
    case freshWater
}
