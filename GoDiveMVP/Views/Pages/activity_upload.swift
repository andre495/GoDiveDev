import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ActivityUploadView: View {
    @Environment(\.modelContext) private var modelContext

    /// Called after a successful import once the progress overlay has finished (Logbook pops **Add activity** and opens **`ViewSingleActivity`** for this id).
    var onSuccessfulImport: ((UUID) -> Void)?

    @State private var showDiveFileImporter = false
    @State private var importOverlay: FitImportOverlayState = .hidden

    init(onSuccessfulImport: ((UUID) -> Void)? = nil) {
        self.onSuccessfulImport = onSuccessfulImport
    }

    var body: some View {
        AppPage(title: "Add activity", showsBackButton: true) {
            ZStack {
                VStack(spacing: AppTheme.Spacing.sm) {
                    addActivitySourcePanel(
                        title: "File upload",
                        systemImage: "doc.badge.arrow.up"
                    ) {
                        showDiveFileImporter = true
                    }

                    addActivitySourcePanel(
                        title: "Manual entry",
                        systemImage: "square.and.pencil"
                    ) {
                        // Placeholder until manual dive creation ships.
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, AppTheme.Spacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if importOverlay != .hidden {
                    fitImportProgressOverlay
                        .zIndex(1)
                }
            }
            .fileImporter(
                isPresented: $showDiveFileImporter,
                allowedContentTypes: [.goDiveFit, .goDiveUddf],
                allowsMultipleSelection: false
            ) { result in
                handleDiveFileImportResult(result)
            }
        }
        .hidesBottomTabBarWhenPushed()
    }

    @ViewBuilder
    private func addActivitySourcePanel(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.accent)

                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(AppTheme.Spacing.lg)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.Colors.surfaceElevated)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.Colors.tabUnselected.opacity(0.2), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(importOverlay.isBlocking)
        .accessibilityLabel(title)
    }

    private var fitImportProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                switch importOverlay {
                case .hidden:
                    EmptyView()
                case .progressing(let progress, let stage):
                    Text("Importing dive")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    ProgressView(value: progress, total: 1.0)
                        .tint(AppTheme.Colors.accent)
                    Text(stage)
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                case .failed(let message):
                    Text("Import failed")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Dismiss") {
                        importOverlay = .hidden
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.tabSelected)
                    .buttonStyle(.plain)
                    .padding(.top, AppTheme.Spacing.sm)
                }
            }
            .padding(AppTheme.Spacing.lg)
            .frame(maxWidth: 320, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.Colors.surfaceElevated)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.Colors.tabUnselected.opacity(0.15), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.28), radius: 14, y: 8)
            .accessibilityAddTraits(.isModal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleDiveFileImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            // Show scrim **synchronously** before read / decode / duplicate check (picker may dismiss same frame).
            importOverlay = .progressing(0.05, "Importing dive…")
            Task(priority: .userInitiated) { @MainActor in
                await yieldForImportOverlayPaint()
                await runDiveFileImport(from: url)
            }
        case .failure(let error):
            importOverlay = .failed(error.localizedDescription)
        }
    }

    /// Lets SwiftUI commit **`importOverlay`** before blocking import work on the main actor.
    @MainActor
    private func yieldForImportOverlayPaint() async {
        await Task.yield()
        await Task.yield()
    }

    @MainActor
    private func runDiveFileImport(from url: URL) async {
        do {
            let ext = url.pathExtension.lowercased()

            withAnimation(.easeInOut(duration: 0.15)) {
                importOverlay = .progressing(0.12, "Reading file…")
            }
            await yieldForImportOverlayPaint()

            let data = try await Task.detached(priority: .userInitiated) {
                if ext == "uddf" {
                    return try UddfDiveFileImport.readUddfFileData(from: url)
                }
                return try FitDiveFileImport.readFitFileData(from: url)
            }.value

            withAnimation(.easeInOut(duration: 0.2)) {
                importOverlay = .progressing(0.38, "Processing dive…")
            }
            await yieldForImportOverlayPaint()

            let outcome: DiveFileImportOutcome
            if ext == "uddf" {
                let activities = try UddfDiveFileDecoder.buildDiveActivities(from: data)
                await yieldForImportOverlayPaint()
                outcome = UddfDiveFileImport.persistImportedActivities(activities, modelContext: modelContext)
            } else {
                let activity = try FitDiveFileDecoder.buildDiveActivity(from: data)
                await yieldForImportOverlayPaint()
                outcome = FitDiveFileImport.persistImportedActivity(activity, modelContext: modelContext)
            }
            if outcome.didSucceed {
                withAnimation(.easeInOut(duration: 0.2)) {
                    importOverlay = .progressing(1.0, "Complete")
                }
                try await Task.sleep(for: FitImportSuccessTiming.sleepAfterCompleteBeforeDismiss)
                importOverlay = .hidden
                if let id = outcome.primaryInsertedDiveId {
                    onSuccessfulImport?(id)
                }
            } else {
                importOverlay = .failed(outcome.userMessage)
            }
        } catch {
            importOverlay = .failed(error.localizedDescription)
        }
    }
}

private enum FitImportOverlayState: Equatable {
    case hidden
    case progressing(Double, String)
    case failed(String)

    var isBlocking: Bool {
        switch self {
        case .hidden: return false
        case .progressing: return true
        case .failed: return true
        }
    }
}

/// After **Complete**, keep the scrim up briefly so the success state reads before dismiss + **`onSuccessfulImport`**.
private enum FitImportSuccessTiming {
    static let sleepAfterCompleteBeforeDismiss: Duration = .milliseconds(800)
}

#Preview {
    let schema = Schema([
        DiveActivity.self,
        DiveBuddyTag.self,
        DiveProfilePoint.self,
        DiveSite.self,
    ])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])
    return ActivityUploadView()
        .modelContainer(container)
}
