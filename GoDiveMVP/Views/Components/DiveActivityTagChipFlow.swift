import SwiftUI

/// Wrapping oval outline tag chips for a dive activity.
struct DiveActivityTagChipFlow: View {
    let tagNames: [String]

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: AppTheme.Spacing.sm)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: AppTheme.Spacing.sm) {
            ForEach(tagNames, id: \.self) { name in
                ActivityTagOvalChipLabel(title: name)
                    .accessibilityLabel("Tag \(name)")
            }
        }
    }
}
