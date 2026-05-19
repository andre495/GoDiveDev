import PhotosUI
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Shared **`Form`** sections for add / edit equipment sheets.
struct EquipmentItemFormContent: View {
    @Binding var form: EquipmentItemFormValues
    @Binding var photoPickerItem: PhotosPickerItem?

    var body: some View {
        Group {
            photoSection
            identitySection
            flagsSection
            purchaseSection
            serviceSection
            notesSection
        }
    }

    private var photoSection: some View {
        Section("Photo") {
            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                HStack(spacing: AppTheme.Spacing.md) {
                    equipmentPhotoThumbnail
                    Text(form.equipmentPhoto == nil ? "Add photo" : "Change photo")
                        .foregroundStyle(AppTheme.Colors.accent)
                }
            }
            .onChange(of: photoPickerItem) { _, newItem in
                guard let newItem else {
                    form.equipmentPhoto = nil
                    return
                }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            form.equipmentPhoto = data
                        }
                    }
                }
            }

            if form.equipmentPhoto != nil {
                Button("Remove photo", role: .destructive) {
                    form.equipmentPhoto = nil
                    photoPickerItem = nil
                }
            }
        }
    }

    @ViewBuilder
    private var equipmentPhotoThumbnail: some View {
        #if canImport(UIKit)
        if let data = form.equipmentPhoto, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            photoPlaceholderIcon
        }
        #else
        photoPlaceholderIcon
        #endif
    }

    private var photoPlaceholderIcon: some View {
        Image(systemName: "camera.fill")
            .font(.title2)
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .frame(width: 56, height: 56)
            .background(AppTheme.Colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var identitySection: some View {
        Section("Equipment") {
            TextField("Manufacturer", text: $form.manufacturer)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("EquipmentForm.Manufacturer")

            TextField("Model", text: $form.model)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("EquipmentForm.Model")

            TextField("Type (e.g. Regulator, BCD)", text: $form.type)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("EquipmentForm.Type")
        }
    }

    private var flagsSection: some View {
        Section {
            Toggle("Retired", isOn: $form.isRetired)
                .accessibilityIdentifier("EquipmentForm.IsRetired")
            Toggle("Auto-add on new dives", isOn: $form.autoAdd)
                .accessibilityIdentifier("EquipmentForm.AutoAdd")
        }
    }

    private var purchaseSection: some View {
        Section("Purchase") {
            Toggle("Include purchase date", isOn: $form.includesPurchaseDate)
            if form.includesPurchaseDate {
                DatePicker("Purchase date", selection: $form.purchaseDate, displayedComponents: .date)
            }
            TextField("Shop", text: $form.purchasedShop)
                .textInputAutocapitalization(.words)
            TextField("Price", text: $form.priceText)
                .keyboardType(.decimalPad)
        }
    }

    private var serviceSection: some View {
        Section("Service") {
            Toggle("Recurring service", isOn: $form.includesRecurringService)
                .accessibilityIdentifier("EquipmentForm.RecurringService")

            if form.includesRecurringService {
                DatePicker("Next service date", selection: $form.nextServiceDate, displayedComponents: .date)
                    .accessibilityIdentifier("EquipmentForm.NextServiceDate")

                recurrenceIntervalRow

                if let days = form.resolvedRecurrenceDays {
                    Text("Last service (estimated): \(estimatedLastServiceLabel(nextDate: form.nextServiceDate, recurrenceDays: days))")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
            }

            TextField("Service notes", text: $form.serviceNotes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private var recurrenceIntervalRow: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Text("Every")
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Stepper(value: $form.recurrenceIntervalCount, in: 1...999) {
                Text("\(form.recurrenceIntervalCount)")
                    .monospacedDigit()
                    .frame(minWidth: 28, alignment: .trailing)
            }

            Picker("Unit", selection: $form.recurrenceUnit) {
                ForEach(EquipmentRecurrenceUnit.allCases) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("EquipmentForm.RecurrenceUnit")
        }
    }

    private func estimatedLastServiceLabel(nextDate: Date, recurrenceDays: Int) -> String {
        guard let last = EquipmentServiceSchedule.lastServiceDate(
            nextServiceDate: nextDate,
            recurrenceDays: recurrenceDays
        ) else {
            return "—"
        }
        return last.formatted(date: .abbreviated, time: .omitted)
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Notes", text: $form.notes, axis: .vertical)
                .lineLimit(4...8)
        }
    }
}
