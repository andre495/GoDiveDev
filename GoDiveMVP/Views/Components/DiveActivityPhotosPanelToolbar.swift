import PhotosUI
import SwiftUI

/// **Media** overview sheet toolbar — trailing **+** opens the photo / video picker.
struct DiveActivityPhotosPanelToolbar: View {
    @Binding var mediaPickerItems: [PhotosPickerItem]

    var body: some View {
        HStack {
            Spacer()
            PhotosPicker(
                selection: $mediaPickerItems,
                maxSelectionCount: 20,
                matching: .any(of: [.images, .videos])
            ) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.accent)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Add photos or videos")
            .accessibilityIdentifier("DiveOverview.MediaAdd")
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
