import Foundation
import Observation
import SharedLogic

/// One editor session: a new tracker (blank, template, calendar event) or an existing one.
@MainActor
@Observable
final class EditorViewModel {
    enum Phase: Equatable {
        case editing
        case saving
        /// Saved: the cat hops onto the card before the editor closes.
        case saved
    }

    var draft: EditorDraft {
        didSet { if draft.title != oldValue.title, !draft.isTitleEmpty { titleMissing = false } }
    }
    var previewSize: CardSize = .small
    private(set) var phase: Phase = .editing
    private(set) var titleMissing = false
    private(set) var rangeInvalid = false
    /// Bumped on every failed save, so the title field shakes each time.
    private(set) var shakes = 0

    let trackerID: String
    let isNew: Bool
    private let store: TrackerStore

    init(store: TrackerStore, draft: EditorDraft, trackerID: String? = nil) {
        self.store = store
        self.draft = draft
        self.trackerID = trackerID ?? TrackerKt.randomTrackerId()
        isNew = trackerID == nil
        previewSize = Self.bestSize(for: draft.look)
    }

    func content(size: CardSize) -> WidgetContent {
        store.content(for: draft, id: trackerID, size: size)
    }

    /// The same tracker drawn in another style, for the style picker thumbnails.
    func content(look: EditorDraft.Look, size: CardSize = .small) -> WidgetContent {
        var other = draft
        other.look = look
        return store.content(for: other, id: trackerID, size: size)
    }

    func setKind(_ kind: EditorDraft.Kind) {
        draft.setKind(kind)
    }

    func setLook(_ look: EditorDraft.Look) {
        draft.look = look
        // Wide styles read better in Medium; switch the preview there, but never back on its own.
        if previewSize == .small, Self.bestSize(for: look) == .medium { previewSize = .medium }
    }

    var sizes: [CardSize] {
        Platform.isMac ? [.small, .medium] : [.small, .medium, .rectangular]
    }

    /// Returns true when saved.
    func save() async -> Bool {
        guard phase == .editing else { return false }
        phase = .saving
        let errors = await store.save(id: trackerID, draft: draft)
        titleMissing = errors.contains(.emptytitle)
        rangeInvalid = errors.contains(.rangeendsbeforestart)
        if errors.isEmpty {
            phase = .saved
            return true
        }
        shakes += 1
        phase = .editing
        return false
    }

    var deleteNote: String { store.deleteNote(for: trackerID) }

    func refreshWidgetCounts() async {
        await store.refreshWidgetCounts()
    }

    func delete() async {
        await store.delete(id: trackerID)
    }

    private static func bestSize(for look: EditorDraft.Look) -> CardSize {
        look == .longCat || look == .bar ? .medium : .small
    }
}
