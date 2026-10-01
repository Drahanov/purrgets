import SharedLogic
import XCTest

/// The editor's Swift draft must survive a round trip through the Kotlin model.
final class EditorDraftTests: XCTestCase {

    private func roundTrip(_ draft: EditorDraft) -> EditorDraft {
        EditorDraft(draft: TrackerDraft(title: draft.title, kind: draft.kotlinKind, appearance: draft.appearance))
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testCountdownWithDotsRoundTrips() {
        var draft = EditorDraft(kind: .countdown)
        draft.title = "Trip"
        draft.day = day(2026, 12, 25)
        draft.look = .dots
        draft.dotShape = .paw
        draft.dotUnit = .week
        draft.fillPast = false
        draft.theme = .marigold
        XCTAssertEqual(roundTrip(draft), draft)
    }

    func testExactTimeKeepsHourAndMinute() {
        var draft = EditorDraft(kind: .countdown)
        draft.day = day(2026, 11, 3)
        draft.time = Calendar.current.date(bySettingHour: 14, minute: 30, second: 0, of: draft.day)
        let back = roundTrip(draft)
        XCTAssertEqual(Calendar.current.dateComponents([.hour, .minute], from: back.time!), DateComponents(hour: 14, minute: 30))
    }

    func testEveryLookOfEveryKindRoundTrips() {
        for kind in EditorDraft.Kind.allCases {
            for look in EditorDraft.looks(for: kind) {
                var draft = EditorDraft(kind: kind)
                draft.look = look
                XCTAssertEqual(roundTrip(draft).look, look, "\(kind) \(look)")
                XCTAssertEqual(roundTrip(draft).kind, kind)
            }
        }
    }

    func testCustomRangeRoundTrips() {
        var draft = EditorDraft(kind: .progress)
        draft.period = .custom
        draft.rangeStart = day(2026, 9, 1)
        draft.rangeEnd = day(2027, 6, 30)
        let back = roundTrip(draft)
        XCTAssertEqual(back.period, .custom)
        XCTAssertEqual(back.rangeStart, draft.rangeStart)
        XCTAssertEqual(back.rangeEnd, draft.rangeEnd)
    }

    func testSwitchingKindKeepsSharedStylesOnly() {
        var draft = EditorDraft(kind: .countdown)
        draft.look = .ring
        draft.setKind(.timeSince)
        XCTAssertEqual(draft.look, .ring)

        draft.look = .fatCat
        draft.setKind(.progress)
        XCTAssertEqual(draft.look, .number, "Progress has no fat cat")
    }

    func testSwitchingKindMovesTheDateToTheRightSideOfToday() {
        let today = Calendar.current.startOfDay(for: .now)
        var draft = EditorDraft(kind: .countdown)
        XCTAssertGreaterThan(draft.day, today)
        draft.setKind(.timeSince)
        XCTAssertLessThanOrEqual(draft.day, today)
        draft.setKind(.countdown)
        XCTAssertGreaterThan(draft.day, today)
    }

    func testPreviewSurvivesABackwardsRange() {
        var draft = EditorDraft(kind: .progress)
        draft.period = .custom
        draft.rangeStart = day(2027, 1, 1)
        draft.rangeEnd = day(2026, 1, 1)
        let tracker = draft.previewTracker(id: "x")
        let range = (tracker.kind as! TrackerKindProgress).range as! ProgressRangeCustom
        XCTAssertEqual(range.start.date, range.end.date)
        XCTAssertEqual(tracker.title, "Progress", "Empty title falls back to a placeholder")
    }
}
