import SharedLogic
import XCTest

@MainActor
final class TrackerStoreTests: XCTestCase {

    func testSaveListsTheTrackerAndReloadsWidgets() async {
        var reloads = 0
        let store = TestEnvironment.makeStore { reloads += 1 }
        await store.load()
        XCTAssertTrue(store.trackers.isEmpty)
        XCTAssertEqual(store.templates.count, 8)

        var draft = EditorDraft(kind: .countdown)
        draft.title = "Holiday"
        let errors = await store.save(id: "a", draft: draft)

        XCTAssertTrue(errors.isEmpty)
        XCTAssertEqual(store.trackers.map(\.title), ["Holiday"])
        XCTAssertEqual(reloads, 1)
    }

    func testInvalidSaveChangesNothing() async {
        var reloads = 0
        let store = TestEnvironment.makeStore { reloads += 1 }
        let errors = await store.save(id: "a", draft: EditorDraft(kind: .countdown))
        XCTAssertEqual(errors, [.emptytitle])
        XCTAssertTrue(store.trackers.isEmpty)
        XCTAssertEqual(reloads, 0)
    }

    func testDuplicateAndDelete() async {
        let store = TestEnvironment.makeStore()
        var draft = EditorDraft(kind: .timeSince)
        draft.title = "No sugar"
        await store.save(id: "a", draft: draft)
        await store.duplicate(store.trackers[0])
        XCTAssertEqual(store.trackers.map(\.title), ["No sugar", "No sugar copy"])

        await store.delete(id: "a")
        XCTAssertEqual(store.trackers.map(\.title), ["No sugar copy"])
    }

    func testPreviewContentFollowsTheDraft() {
        let store = TestEnvironment.makeStore()
        var draft = EditorDraft(kind: .countdown, today: TestEnvironment.now)
        draft.title = "Exam"
        draft.day = Calendar.current.date(byAdding: .day, value: 10, to: Calendar.current.startOfDay(for: TestEnvironment.now))!
        draft.look = .ring

        let content = store.content(for: draft, id: "p", size: .small)
        XCTAssertEqual(content.title, "Exam")
        XCTAssertEqual(content.value, "10")
        XCTAssertEqual(content.style, .ring)
    }
}

@MainActor
final class EditorViewModelTests: XCTestCase {

    func testNewTrackerSaves() async {
        let store = TestEnvironment.makeStore()
        var draft = EditorDraft(kind: .countdown)
        draft.title = "Concert"
        let model = EditorViewModel(store: store, draft: draft)

        XCTAssertTrue(model.isNew)
        let saved = await model.save()
        XCTAssertTrue(saved)
        XCTAssertEqual(model.phase, .saved)
        XCTAssertEqual(store.trackers.first?.id, model.trackerID)
    }

    func testMissingTitleShakesAndStaysOpen() async {
        let store = TestEnvironment.makeStore()
        let model = EditorViewModel(store: store, draft: EditorDraft(kind: .countdown))

        let saved = await model.save()
        XCTAssertFalse(saved)
        XCTAssertTrue(model.titleMissing)
        XCTAssertEqual(model.shakes, 1)
        XCTAssertEqual(model.phase, .editing)

        model.draft.title = "Fixed"
        XCTAssertFalse(model.titleMissing, "Typing a title clears the error")
    }

    func testBackwardsRangeIsReported() async {
        let store = TestEnvironment.makeStore()
        var draft = EditorDraft(kind: .progress)
        draft.title = "Term"
        draft.period = .custom
        draft.rangeEnd = Calendar.current.date(byAdding: .day, value: -5, to: draft.rangeStart)!
        let model = EditorViewModel(store: store, draft: draft)

        let saved = await model.save()
        XCTAssertFalse(saved)
        XCTAssertTrue(model.rangeInvalid)
    }

    func testEditingKeepsTheIdAndUpdatesInPlace() async {
        let store = TestEnvironment.makeStore()
        var draft = EditorDraft(kind: .countdown)
        draft.title = "Old"
        await store.save(id: "a", draft: draft)

        let model = EditorViewModel(store: store, draft: EditorDraft(tracker: store.trackers[0]), trackerID: "a")
        XCTAssertFalse(model.isNew)
        model.draft.title = "New"
        _ = await model.save()
        XCTAssertEqual(store.trackers.map(\.title), ["New"])
        XCTAssertEqual(store.trackers.map(\.id), ["a"])
    }

    func testWideStylesMoveThePreviewToMedium() {
        let store = TestEnvironment.makeStore()
        let model = EditorViewModel(store: store, draft: EditorDraft(kind: .countdown))
        XCTAssertEqual(model.previewSize, .small)
        model.setLook(.longCat)
        XCTAssertEqual(model.previewSize, .medium)
        model.setLook(.number)
        XCTAssertEqual(model.previewSize, .medium, "Never switches back on its own")
    }
}
