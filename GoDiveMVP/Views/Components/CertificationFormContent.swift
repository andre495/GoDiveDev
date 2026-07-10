import PhotosUI
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Focus targets for certification text fields (optional — onboarding keyboard chrome).
enum CertificationFormField: Hashable, Sendable {
    case certName
    case agency
    case certNumber
    case instructor
    case instructorNumber
    case diveShop
    case diveShopNumber
}

/// Shared **`Form`** sections for add / edit certification sheets.
struct CertificationFormContent: View {
    @Binding var form: CertificationFormValues
    @Binding var frontPhotoPickerItem: PhotosPickerItem?
    @Binding var backPhotoPickerItem: PhotosPickerItem?
    @Binding var cardPhotoPreview: CertificationCardPhotoPreviewSelection?
    var focusedField: FocusState<CertificationFormField?>.Binding?
    var disablesTextAutocorrection = false

    @State private var isScanningCard = false
    @State private var frontCardScanTask: Task<Void, Never>?
    @State private var backCardScanTask: Task<Void, Never>?
    @State private var scanningPhotoLabel: String?

    var body: some View {
        Group {
            cardPhotosSection
            certificationSection
            instructorSection
            cardTypeSection
        }
    }

    private var cardPhotosSection: some View {
        Section {
            cardPhotoRow(
                label: "Front",
                imageData: form.certFrontPicture,
                pickerSelection: $frontPhotoPickerItem,
                onLoaded: { data in
                    form.certFrontPicture = data
                    scanPADICard(from: data, photoLabel: "Front")
                },
                onRemove: {
                    frontCardScanTask?.cancel()
                    frontCardScanTask = nil
                    updateScanningIndicator()
                    form.certFrontPicture = nil
                    frontPhotoPickerItem = nil
                },
                accessibilityRoot: "CertificationForm.FrontPhoto",
                showsScanningIndicator: isScanningCard && scanningPhotoLabel == "Front"
            )

            cardPhotoRow(
                label: "Back",
                imageData: form.certBackPicture,
                pickerSelection: $backPhotoPickerItem,
                onLoaded: { data in
                    form.certBackPicture = data
                    scanPADICard(from: data, photoLabel: "Back")
                },
                onRemove: {
                    backCardScanTask?.cancel()
                    backCardScanTask = nil
                    updateScanningIndicator()
                    form.certBackPicture = nil
                    backPhotoPickerItem = nil
                },
                accessibilityRoot: "CertificationForm.BackPhoto",
                showsScanningIndicator: isScanningCard && scanningPhotoLabel == "Back"
            )
        } header: {
            Text("Card photos")
        } footer: {
            Text("Adding a PADI card photo can auto-fill agency, certification name, number, date, instructor, and shop fields.")
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
    }

    @ViewBuilder
    private func cardPhotoRow(
        label: String,
        imageData: Data?,
        pickerSelection: Binding<PhotosPickerItem?>,
        onLoaded: @escaping (Data) -> Void,
        onRemove: @escaping () -> Void,
        accessibilityRoot: String,
        showsScanningIndicator: Bool = false
    ) -> some View {
        if imageData != nil {
            HStack(spacing: AppTheme.Spacing.md) {
                Button {
                    if let imageData {
                        CertificationCardPhotoPreviewPresentation.schedulePresent(
                            selection: $cardPhotoPreview,
                            label: label,
                            imageData: imageData
                        )
                    }
                } label: {
                    cardThumbnail(imageData: imageData)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View \(label.lowercased()) of certification card")
                .accessibilityIdentifier("\(accessibilityRoot).Preview")

                CertificationCardPhotoPicker(
                    pickerSelection: pickerSelection,
                    label: label,
                    imageData: imageData,
                    showsScanningIndicator: showsScanningIndicator,
                    accessibilityRoot: accessibilityRoot,
                    onLoaded: onLoaded,
                    onPickerActivated: dismissCertificationKeyboardIfNeeded
                )
            }
        } else {
            CertificationCardPhotoPicker(
                pickerSelection: pickerSelection,
                label: label,
                imageData: imageData,
                showsScanningIndicator: showsScanningIndicator,
                accessibilityRoot: accessibilityRoot,
                onLoaded: onLoaded,
                onPickerActivated: dismissCertificationKeyboardIfNeeded
            )
        }

        if imageData != nil {
            Button("Remove \(label.lowercased()) photo", role: .destructive, action: onRemove)
        }
    }

    private func dismissCertificationKeyboardIfNeeded() {
        focusedField?.wrappedValue = nil
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
            certificationTextField(
                "Certification name (e.g. Rescue Diver)",
                text: $form.certName,
                field: .certName,
                capitalization: .words,
                accessibilityIdentifier: "CertificationForm.CertName"
            )

            certificationTextField(
                "Agency (e.g. PADI, NAUI)",
                text: $form.agency,
                field: .agency,
                capitalization: .characters,
                accessibilityIdentifier: "CertificationForm.Agency"
            )

            certificationTextField(
                "Certification number",
                text: $form.certNumber,
                field: .certNumber,
                capitalization: .never,
                accessibilityIdentifier: "CertificationForm.CertNumber"
            )

            DatePicker("Date attained", selection: $form.dateAttained, displayedComponents: .date)
                .accessibilityIdentifier("CertificationForm.DateAttained")
        }
    }

    private var instructorSection: some View {
        Section("Instructor & shop") {
            certificationTextField(
                "Instructor name",
                text: $form.instructor,
                field: .instructor,
                capitalization: .words,
                accessibilityIdentifier: "CertificationForm.Instructor"
            )

            certificationTextField(
                "Instructor number",
                text: $form.instructorNumber,
                field: .instructorNumber,
                capitalization: .never,
                accessibilityIdentifier: "CertificationForm.InstructorNumber"
            )

            certificationTextField(
                "Dive shop",
                text: $form.diveShop,
                field: .diveShop,
                capitalization: .words,
                accessibilityIdentifier: "CertificationForm.DiveShop"
            )

            certificationTextField(
                "Shop identification number",
                text: $form.diveShopNumber,
                field: .diveShopNumber,
                capitalization: .never,
                accessibilityIdentifier: "CertificationForm.DiveShopNumber"
            )
        }
    }

    @ViewBuilder
    private func certificationTextField(
        _ placeholder: String,
        text: Binding<String>,
        field: CertificationFormField,
        capitalization: TextInputAutocapitalization,
        accessibilityIdentifier: String
    ) -> some View {
        let baseField = TextField(placeholder, text: text)
            .textInputAutocapitalization(capitalization)
            .accessibilityIdentifier(accessibilityIdentifier)

        if let focusedField {
            baseField
                .focused(focusedField, equals: field)
                .autocorrectionDisabled(disablesTextAutocorrection)
                .textContentType(.none)
                .keyboardType(.asciiCapable)
        } else {
            baseField
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

    private func scanPADICard(from imageData: Data, photoLabel: String) {
        if photoLabel == "Front" {
            frontCardScanTask?.cancel()
        } else {
            backCardScanTask?.cancel()
        }
        scanningPhotoLabel = photoLabel
        updateScanningIndicator()

        let task = Task {
            let parsed = await CertificationCardTextRecognition.parsePADICard(
                from: imageData,
                photoLabel: photoLabel
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if photoLabel == "Front" {
                    frontCardScanTask = nil
                } else {
                    backCardScanTask = nil
                }
                updateScanningIndicator()
                if let parsed {
                    form.applyPADIParseResult(parsed)
                }
            }
        }

        if photoLabel == "Front" {
            frontCardScanTask = task
        } else {
            backCardScanTask = task
        }
    }

    private func updateScanningIndicator() {
        let frontScanning = frontCardScanTask != nil
        let backScanning = backCardScanTask != nil
        isScanningCard = frontScanning || backScanning
        if !frontScanning && scanningPhotoLabel == "Front" {
            scanningPhotoLabel = backScanning ? "Back" : nil
        } else if !backScanning && scanningPhotoLabel == "Back" {
            scanningPhotoLabel = frontScanning ? "Front" : nil
        } else if frontScanning {
            scanningPhotoLabel = "Front"
        } else if backScanning {
            scanningPhotoLabel = "Back"
        } else {
            scanningPhotoLabel = nil
        }
    }
}

/// Photos picker row that observes `@Binding` selection reliably and resets after load so **Change photo** works.
private struct CertificationCardPhotoPicker: View {
    @Binding var pickerSelection: PhotosPickerItem?

    let label: String
    let imageData: Data?
    let showsScanningIndicator: Bool
    let accessibilityRoot: String
    let onLoaded: (Data) -> Void
    let onPickerActivated: () -> Void

    var body: some View {
        PhotosPicker(selection: $pickerSelection, matching: .images) {
            CertificationCardPhotoPickerRowContent(
                label: label,
                imageData: imageData,
                showsScanningIndicator: showsScanningIndicator
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onChange(of: pickerSelection) { _, newItem in
            guard let newItem else { return }
            onPickerActivated()
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        onLoaded(data)
                        pickerSelection = nil
                    }
                }
            }
        }
        .accessibilityIdentifier(accessibilityRoot)
    }
}

private struct CertificationCardPhotoPickerRowContent: View {
    let label: String
    let imageData: Data?
    let showsScanningIndicator: Bool

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            if imageData == nil {
                CertificationCardPhotoThumbnail(imageData: imageData)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                if showsScanningIndicator {
                    Text("Reading card…")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.accent)
                } else {
                    Text(imageData == nil ? "Add photo" : "Change photo")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.accent)
                }
            }
            Spacer(minLength: 0)
            if showsScanningIndicator {
                ProgressView()
                    .accessibilityHidden(true)
            }
        }
    }
}

private struct CertificationCardPhotoThumbnail: View {
    let imageData: Data?

    var body: some View {
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
}

struct CertificationCardPhotoPreviewSelection: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let imageData: Data

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

enum CertificationCardPhotoPreviewPresentation {
    @MainActor
    static func schedulePresent(
        selection: Binding<CertificationCardPhotoPreviewSelection?>,
        label: String,
        imageData: Data
    ) {
        let preview = CertificationCardPhotoPreviewSelection(label: label, imageData: imageData)
        Task { @MainActor in
            await Task.yield()
            selection.wrappedValue = preview
        }
    }
}

extension View {
    func certificationCardPhotoPreviewCover(
        _ selection: Binding<CertificationCardPhotoPreviewSelection?>
    ) -> some View {
        fullScreenCover(item: selection) { preview in
            CertificationCardPhotoFullscreenPreview(
                label: preview.label,
                imageData: preview.imageData
            )
        }
    }
}

private struct CertificationCardPhotoFullscreenPreview: View {
    @Environment(\.dismiss) private var dismiss

    let label: String
    let imageData: Data

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            #if canImport(UIKit)
            if let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(AppTheme.Spacing.md)
                    .accessibilityLabel("\(label) of certification card")
            }
            #endif

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .appToolbarIconButtonLabel()
                    }
                    .appStandaloneIconButtonStyle()
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Close")
                }
                .padding(AppTheme.Spacing.md)

                Spacer(minLength: 0)
            }
        }
        .accessibilityIdentifier("CertificationForm.CardPhotoPreview")
    }
}
