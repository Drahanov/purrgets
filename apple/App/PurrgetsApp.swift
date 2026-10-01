import SharedLogic
import SwiftUI
import WidgetKit

@main
struct PurrgetsApp: App {
    var body: some Scene {
        WindowGroup {
            DebugHomeView()
        }
    }
}

/// Temporary home screen until the app module is built: add sample trackers so the
/// widget has something to show, and see them drawn with the widget's own views.
struct DebugHomeView: View {
    @State private var trackers: [Tracker] = []
    private let container = Purrgets.container

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 16)], spacing: 16) {
                    ForEach(trackers, id: \.id) { tracker in
                        TrackerCardPreview(content: WidgetContent(state: container.renderTracker.invoke(tracker: tracker, maxDots: 100)), size: .small)
                    }
                }
                .padding()
            }
            .overlay {
                if trackers.isEmpty {
                    ContentUnavailableView("No trackers", systemImage: "pawprint", description: Text("Add the samples, then add the Purrgets widget."))
                }
            }
            .navigationTitle("Purrgets")
            .toolbar {
                Button("Add samples", action: addSamples)
                Button("Delete all", role: .destructive, action: deleteAll)
            }
        }
        .task {
            await reload()
            // For automated checks: `--add-samples` fills the store on launch.
            if ProcessInfo.processInfo.arguments.contains("--add-samples"), trackers.isEmpty { addSamples() }
        }
    }

    private func addSamples() {
        Task {
            for template in container.listTemplates.invoke() {
                _ = try? await container.saveTracker.invoke(id: TrackerKt.randomTrackerId(), draft: template.draft)
            }
            await reload()
        }
    }

    private func deleteAll() {
        Task {
            for tracker in trackers {
                try? await container.deleteTracker.invoke(id: tracker.id)
            }
            await reload()
        }
    }

    private func reload() async {
        trackers = (try? await container.listTrackers.invoke()) ?? []
        WidgetCenter.shared.reloadAllTimelines()
    }
}
