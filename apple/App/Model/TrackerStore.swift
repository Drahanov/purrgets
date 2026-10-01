import Foundation
import Observation
import SharedLogic

/// The app's trackers, kept in memory for the screens. Reads and writes through the Kotlin
/// use cases, and tells WidgetKit to redraw after every change. One per app process.
@MainActor
@Observable
final class TrackerStore {
    private(set) var trackers: [Tracker] = []
    private(set) var templates: [Template] = []
    private(set) var isLoaded = false

    private let container: AppContainer
    private let reloadWidgets: () -> Void

    init(container: AppContainer, reloadWidgets: @escaping () -> Void) {
        self.container = container
        self.reloadWidgets = reloadWidgets
    }

    var calendarAvailable: Bool { container.loadCalendarEvents != nil }

    func load() async {
        trackers = (try? await container.listTrackers.invoke()) ?? []
        templates = container.listTemplates.invoke()
        isLoaded = true
    }

    func tracker(id: String) -> Tracker? { trackers.first { $0.id == id } }

    /// Saves a new or edited tracker. Returns the validation errors, empty when saved.
    @discardableResult
    func save(id: String, draft: EditorDraft) async -> [ValidationError] {
        let result: SaveResult
        do {
            result = try await container.saveTracker.invoke(id: id, title: draft.title, kind: draft.kotlinKind, appearance: draft.appearance)
        } catch {
            return []
        }
        if let invalid = result as? SaveResultInvalid { return invalid.errors }
        await changed()
        return []
    }

    func delete(id: String) async {
        try? await container.deleteTracker.invoke(id: id)
        await changed()
    }

    /// A copy right after the original, titled "… copy".
    func duplicate(_ tracker: Tracker) async {
        var draft = EditorDraft(tracker: tracker)
        draft.title = "\(tracker.title) copy"
        await save(id: TrackerKt.randomTrackerId(), draft: draft)
    }

    /// What the tracker shows right now, for a card of [size].
    func content(for tracker: Tracker, size: CardSize) -> WidgetContent {
        WidgetContent(state: container.renderTracker.invoke(tracker: tracker, maxDots: size.maxDots))
    }

    /// The editor's live preview.
    func content(for draft: EditorDraft, id: String, size: CardSize) -> WidgetContent {
        content(for: draft.previewTracker(id: id), size: size)
    }

    func calendarEvents() async -> CalendarEventsResult {
        guard let load = container.loadCalendarEvents else { return .unavailable }
        guard let result = try? await load.invoke() else { return .events([]) }
        if let events = result as? CalendarResultEvents { return .events(events.events) }
        return .noAccess
    }

    func draft(from event: CalendarEvent) -> EditorDraft {
        EditorDraft(draft: container.draftFromEvent.invoke(event: event))
    }

    private func changed() async {
        trackers = (try? await container.listTrackers.invoke()) ?? trackers
        reloadWidgets()
    }
}

enum CalendarEventsResult {
    case events([CalendarEvent])
    case noAccess
    case unavailable
}
