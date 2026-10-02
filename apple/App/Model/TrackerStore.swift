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
    /// Widgets per tracker id. Apps can't remove widgets, so deleting a tracker says how many are left.
    private(set) var widgetCounts: [String: Int] = [:]

    private let container: AppContainer
    private let reloadWidgets: () -> Void
    private let countWidgets: () async -> [String: Int]

    init(container: AppContainer, countWidgets: @escaping () async -> [String: Int] = { [:] }, reloadWidgets: @escaping () -> Void) {
        self.container = container
        self.countWidgets = countWidgets
        self.reloadWidgets = reloadWidgets
    }

    var calendarAvailable: Bool { container.loadCalendarEvents != nil }

    func load() async {
        trackers = (try? await container.listTrackers.invoke()) ?? []
        templates = container.listTemplates.invoke()
        isLoaded = true
        await refreshWidgetCounts()
    }

    func refreshWidgetCounts() async {
        widgetCounts = await countWidgets()
    }

    /// The delete dialog's note on the tracker's widgets.
    func deleteNote(for id: String) -> String {
        let place = Platform.isMac ? "desktop" : "Home Screen"
        switch widgetCounts[id] ?? 0 {
        case 0: return "It isn't on any widget."
        case 1: return "It's on 1 widget. That widget will ask you to pick another tracker, or you can remove it from your \(place)."
        case let count: return "It's on \(count) widgets. They will ask you to pick another tracker, or you can remove them from your \(place)."
        }
    }

    func tracker(id: String) -> Tracker? { trackers.first { $0.id == id } }

    /// Saves a new or edited tracker.
    @discardableResult
    func save(id: String, draft: EditorDraft) async -> SaveOutcome {
        let result: SaveResult
        do {
            result = try await container.saveTracker.invoke(id: id, title: draft.title, kind: draft.kotlinKind, appearance: draft.appearance)
        } catch {
            CatLog.app.error("save \(id, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            return .failed
        }
        if let invalid = result as? SaveResultInvalid { return .invalid(invalid.errors) }
        await changed()
        return .saved
    }

    /// Set when a delete or duplicate from Home fails, for an alert there.
    var failure: String?

    func delete(id: String) async {
        do {
            try await container.deleteTracker.invoke(id: id)
        } catch {
            CatLog.app.error("delete \(id, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            failure = "Couldn't delete the tracker. Please try again."
        }
        await changed()
    }

    /// A copy right after the original, titled "… copy".
    func duplicate(_ tracker: Tracker) async {
        var draft = EditorDraft(tracker: tracker)
        draft.title = "\(tracker.title) copy"
        if await save(id: TrackerKt.randomTrackerId(), draft: draft) == .failed {
            failure = "Couldn't duplicate the tracker. Please try again."
        }
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

enum SaveOutcome: Equatable {
    case saved
    case invalid([ValidationError])
    /// Storage failed; nothing was saved.
    case failed
}

enum CalendarEventsResult {
    case events([CalendarEvent])
    case noAccess
    case unavailable
}
