import PhotosUI
import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Circular profile photo with **PhotosPicker** and crop sheet (camera badge to change).
struct ProfileAvatarEditor: View {
    var diameter: CGFloat = 120

    private var cameraBadgeSize: CGFloat {
        max(32, diameter * 0.27)
    }

    private var placeholderIconSize: CGFloat {
        diameter * 0.47
    }

    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var modelContext

    @State private var photoPickerItem: PhotosPickerItem?
    @State private var saveErrorMessage: String?
    #if canImport(UIKit)
    @State private var cropDraft: ProfilePhotoCropDraft?
    #endif

    var body: some View {
        PhotosPicker(selection: $photoPickerItem, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                ProfileAvatarView(
                    profilePhoto: profile.profilePhoto,
                    diameter: diameter,
                    iconFont: .system(size: placeholderIconSize)
                )
                .shadow(color: .black.opacity(0.2), radius: 10, y: 4)

                Image(systemName: "camera.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: cameraBadgeSize, height: cameraBadgeSize)
                    .background(Circle().fill(AppTheme.Colors.accent))
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                    }
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            profile.profilePhoto == nil ? "Add profile photo" : "Change profile photo"
        )
        .accessibilityIdentifier("Profile.AvatarPicker")
        .onChange(of: photoPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await prepareCrop(from: newItem)
            }
        }
        #if canImport(UIKit)
        .sheet(item: $cropDraft) { draft in
            ProfilePhotoCropSheet(
                sourceImage: draft.image,
                onSave: { data in
                    applyCroppedPhoto(data)
                    cropDraft = nil
                    photoPickerItem = nil
                },
                onCancel: {
                    cropDraft = nil
                    photoPickerItem = nil
                }
            )
        }
        #endif
        .alert("Could not save photo", isPresented: saveErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "Try again.")
        }
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )
    }

    @MainActor
    private func prepareCrop(from item: PhotosPickerItem) async {
        #if canImport(UIKit)
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }
            cropDraft = ProfilePhotoCropDraft(image: image)
        } catch {
            saveErrorMessage = error.localizedDescription
            photoPickerItem = nil
        }
        #endif
    }

    @MainActor
    private func applyCroppedPhoto(_ data: Data) {
        profile.profilePhoto = data
        do {
            try modelContext.save()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }

}
