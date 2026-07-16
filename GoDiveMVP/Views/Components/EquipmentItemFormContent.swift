import PhotosUI
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Shared **`Form`** sections for add / edit equipment sheets.
struct EquipmentItemFormContent: View {
    @Binding var form: EquipmentItemFormValues
    @Binding var photoPickerItem: PhotosPickerItem?
    var clearsListRowBackgrounds = false

    var body: some View {
        Group {
            photoSection
            identitySection
            flagsSection
            purchaseSection
            serviceSection
            notesSection
            retiredSection
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
            .modifier(EquipmentItemFormListRowBackground(clears: clearsListRowBackgrounds))

            if form.equipmentPhoto != nil {
                Button("Remove photo", role: .destructive) {
                    form.equipmentPhoto = nil
                    photoPickerItem = nil
                }
                .modifier(EquipmentItemFormListRowBackground(clears: clearsListRowBackgrounds))
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
                .modifier(EquipmentItemFormListRowBackground(clears: clearsListRowBackgrounds))

            TextField("Model", text: $form.model)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("EquipmentForm.Model")
                .modifier(EquipmentItemFormListRowBackground(clears: clearsListRowBackgrounds))

            Picker("Gear type", selection: $form.gearType) {
                ForEach(EquipmentGearType.allCases) { gearType in
                    Text(gearType.displayName).tag(gearType)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("EquipmentForm.GearType")
            .modifier(EquipmentItemFormListRowBackground(clears: clearsListRowBackgrounds))
        }
    }

    private var flagsSection: some View {
        Section {
            Toggle("Auto-add on new dives", isOn: $form.autoAdd)
                .accessibilityIdentifier("EquipmentForm.AutoAdd")
                .modifier(EquipmentItemFormListRowBackground(clears: clearsListRowBackgrounds))
        }
    }

    private var retiredSection: some View {
        Section {
            Toggle(isOn: $form.isRetired) {
                Text("Retired")
                    .foregroundStyle(Color.red)
            }
            .tint(.red)
            .accessibilityIdentifier("EquipmentForm.IsRetired")
            .modifier(EquipmentItemFormListRowBackground(clears: clearsListRowBackgrounds))
        }
    }

    private var purchaseSection: some View {
        Section("Purchase") {
            Toggle("Include purchase date", isOn: $form.includesPurchaseDate)
                .modifier(EquipmentItemFormListRowBackground(clears: clearsListRowBackgrounds))
            if form.includesPurchaseDate {
                DatePicker("Purchase date", selection: $form.purchaseDate, displayedComponents: .date)
                    .modifier(EquipmentItemFormListRowBackground(clears: clearsListRowBackgrounds))
            }
            TextField("Shop", text: $form.purchasedShop)
                .textInputAutocapitalization(.words)
                .modifier(EquipmentItemFormListRowBackground(clears: clearsListRowBackgrounds))
            TextField("Price", text: $form.priceText)
                .keyboardType(.decimalPad)
                .modifier(EquipmentItemFormListRowBackground(clears: clearsListRowBackgrounds))
        }
    }

    private var serviceSection: some View {
        Section("Service") {
            Toggle("Recurring service", isOn: $form.includesRecurringService)
                .accessibilityIdentifier("EquipmentForm.RecurringService")
                .modifier(EquipmentItemFormListRowBackground(clears: clearsListRowBackgrounds))

            if form.includesRecurringService {
                DatePicker("Next service date", selection: $form.nextServiceDate, displayedComponents: .date)
                    .accessibilityIdentifier("EquipmentForm.NextServiceDate")
                    .modifier(EquipmentItemFormListRowBackground(clears: clearsListRowBackgrounds))

                recurrenceIntervalRow
                    .modifier(EquipmentItemFormListRowBackground(clears: clearsListRowBackgrounds))

                if let days = form.resolvedRecurrenceDays {
                    Text("Last service (estimated): \(estimatedLastServiceLabel(nextDate: form.nextServiceDate, recurrenceDays: days))")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .modifier(EquipmentItemFormListRowBackground(clears: clearsListRowBackgrounds))
                }
            }

            TextField("Service notes", text: $form.serviceNotes, axis: .vertical)
                .lineLimit(3...6)
                .modifier(EquipmentItemFormListRowBackground(clears: clearsListRowBackgrounds))
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
                .modifier(EquipmentItemFormListRowBackground(clears: clearsListRowBackgrounds))
        }
    }
}

private struct EquipmentItemFormListRowBackground: ViewModifier {
    let clears: Bool

    func body(content: Content) -> some View {
        if clears {
            content.listRowBackground(Color.clear)
        } else {
            content
        }
    }
}
