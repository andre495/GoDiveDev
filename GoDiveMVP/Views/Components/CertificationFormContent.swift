import PhotosUI
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Shared **`Form`** sections for add / edit certification sheets.
struct CertificationFormContent: View {
    @Binding var form: CertificationFormValues
    @Binding var frontPhotoPickerItem: PhotosPickerItem?
    @Binding var backPhotoPickerItem: PhotosPickerItem?

    var body: some View {
        Group {
            cardPhotosSection
            certificationSection
            instructorSection
            cardTypeSection
        }
    }

    private var cardPhotosSection: some View {
        Section("Card photos") {
            cardPhotoRow(
                label: "Front",
                imageData: form.certFrontPicture,
                pickerSelection: $frontPhotoPickerItem,
                onLoaded: { form.certFrontPicture = $0 },
                onRemove: {
                    form.certFrontPicture = nil
                    frontPhotoPickerItem = nil
                },
                accessibilityRoot: "CertificationForm.FrontPhoto"
            )

            cardPhotoRow(
                label: "Back",
                imageData: form.certBackPicture,
                pickerSelection: $backPhotoPickerItem,
                onLoaded: { form.certBackPicture = $0 },
                onRemove: {
                    form.certBackPicture = nil
                    backPhotoPickerItem = nil
                },
                accessibilityRoot: "CertificationForm.BackPhoto"
            )
        }
    }

    @ViewBuilder
    private func cardPhotoRow(
        label: String,
        imageData: Data?,
        pickerSelection: Binding<PhotosPickerItem?>,
        onLoaded: @escaping (Data) -> Void,
        onRemove: @escaping () -> Void,
        accessibilityRoot: String
    ) -> some View {
        PhotosPicker(selection: pickerSelection, matching: .images) {
            HStack(spacing: AppTheme.Spacing.md) {
                cardThumbnail(imageData: imageData)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(imageData == nil ? "Add photo" : "Change photo")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.accent)
                }
                Spacer(minLength: 0)
            }
        }
        .onChange(of: pickerSelection.wrappedValue) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run { onLoaded(data) }
                }
            }
        }
        .accessibilityIdentifier(accessibilityRoot)

        if imageData != nil {
            Button("Remove \(label.lowercased()) photo", role: .destructive, action: onRemove)
        }
    }

    @ViewBuilder
    private func cardThumbnail(imageData: Data?) -> some View {
        #if canImport(UIKit)
        if let imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            cardThumbnailPlaceholder
        }
        #else
        cardThumbnailPlaceholder
        #endif
    }

    private var cardThumbnailPlaceholder: some View {
        Image(systemName: "person.text.rectangle.fill")
            .font(.title3)
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .frame(width: 56, height: 40)
            .background(AppTheme.Colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var certificationSection: some View {
        Section("Certification") {
            TextField("Certification name (e.g. Rescue Diver)", text: $form.certName)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("CertificationForm.CertName")

            TextField("Agency (e.g. PADI, NAUI)", text: $form.agency)
                .textInputAutocapitalization(.characters)
                .accessibilityIdentifier("CertificationForm.Agency")

            TextField("Certification number", text: $form.certNumber)
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("CertificationForm.CertNumber")

            DatePicker("Date attained", selection: $form.dateAttained, displayedComponents: .date)
                .accessibilityIdentifier("CertificationForm.DateAttained")
        }
    }

    private var instructorSection: some View {
        Section("Instructor & shop") {
            TextField("Instructor name", text: $form.instructor)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("CertificationForm.Instructor")

            TextField("Instructor number", text: $form.instructorNumber)
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("CertificationForm.InstructorNumber")

            TextField("Dive shop", text: $form.diveShop)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("CertificationForm.DiveShop")
        }
    }

    private var cardTypeSection: some View {
        Section {
            Picker("Type", selection: $form.cardType) {
                ForEach(CertificationCardType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("CertificationForm.CardType")
        } footer: {
            Text("Certification cards can appear on your profile when they are the newest certification-type entry.")
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
    }
}
