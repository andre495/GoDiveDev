import SwiftUI

/// Primary sections on the **Field Guide** tab.
enum FieldGuideSection: String, CaseIterable, Identifiable {
    case fieldGuide
    case sightings

    var id: String { rawValue }

    var accessibilityLabel: String {
        switch self {
        case .fieldGuide: "Field Guide"
        case .sightings: "Sightings"
        }
    }

    var systemImage: String {
        switch self {
        case .fieldGuide: "book.fill"
        case .sightings: "camera.fill"
        }
    }
}

/// Full-width segmented **Field Guide** / **Sightings** control.
struct FieldGuideSectionToggle: View {
    @Binding var selection: FieldGuideSection

    var body: some View {
        HStack(spacing: 4) {
            ForEach(FieldGuideSection.allCases) { section in
                Button {
                    selection = section
                } label: {
                    Label {
                        Text(section.accessibilityLabel)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    } icon: {
                        Image(systemName: section.systemImage)
                            .font(.subheadline.weight(.semibold))
                    }
                    .labelStyle(.titleAndIcon)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .foregroundStyle(
                        selection == section
                            ? AppTheme.Colors.textPrimary
                            : AppTheme.Colors.tabUnselected
                    )
                    .background {
                        if selection == section {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(AppTheme.Colors.surfaceElevated)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.accessibilityLabel)
                .accessibilityAddTraits(selection == section ? .isSelected : [])
                .accessibilityIdentifier("FieldGuide.Section.\(section.rawValue.capitalized)")
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.tabUnselected.opacity(0.12))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Field Guide section")
    }
}
