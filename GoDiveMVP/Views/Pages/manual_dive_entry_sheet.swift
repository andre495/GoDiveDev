import SwiftUI

/// Confirms date and site name before **`DiveActivityManualCreation`** inserts a manual dive.
struct ManualDiveEntrySheet: View {
    @Environment(\.dismiss) private var dismiss

    var onConfirm: (ManualDiveEntryInput) -> Void

    @State private var startTime = Date()
    @State private var siteNameText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "Date",
                        selection: $startTime,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .accessibilityIdentifier("ManualDiveEntry.Date")

                    TextField(
                        "Site name",
                        text: $siteNameText,
                        prompt: Text("e.g. Salt Pier")
                    )
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("ManualDiveEntry.SiteName")
                } footer: {
                    Text("Site name is optional.")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("New dive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("ManualDiveEntry.Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onConfirm(ManualDiveEntryInput(startTime: startTime, siteNameText: siteNameText))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("ManualDiveEntry.Confirm")
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .appSheetPresentationChrome()
        .accessibilityIdentifier("ManualDiveEntry.Sheet")
    }
}
