import AppIntents
import SharedLogic

/// A tracker as the widget's settings see it: just an id and a title.
/// iOS stores the id per widget and hands it back on every refresh.
struct TrackerEntity: AppEntity {
    let id: String
    let title: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Tracker"
    static var defaultQuery = TrackerQuery()

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
}

/// The options list in "Edit Widget": read from trackers.json through Kotlin.
struct TrackerQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [TrackerEntity] {
        try await all().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [TrackerEntity] {
        try await all()
    }

    /// A new widget starts with the newest tracker, so it never shows up empty.
    func defaultResult() async -> TrackerEntity? {
        try? await all().last
    }

    private func all() async throws -> [TrackerEntity] {
        try await Purrgets.container.listTrackers.invoke().map { TrackerEntity(id: $0.id, title: $0.title) }
    }
}

struct SelectTrackerIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose a tracker"
    static var description = IntentDescription("The tracker this widget shows.")

    @Parameter(title: "Tracker")
    var tracker: TrackerEntity?
}
