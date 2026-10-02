import Foundation

/// What the editor edits: a plain Swift value, so controls can bind to it directly.
/// It becomes a Kotlin `TrackerKind` in EditorDraft+Kotlin.swift.
struct EditorDraft: Equatable {
    enum Kind: String, CaseIterable, Identifiable {
        case countdown, timeSince, progress
        var id: Self { self }
    }

    /// The widget style. Each kind accepts only some of them (see `looks(for:)`).
    enum Look: String, CaseIterable, Identifiable {
        case number, ring, dots, bar, longCat
        var id: Self { self }
    }

    enum Period: String, CaseIterable, Identifiable {
        case year, month, week, custom
        var id: Self { self }
    }

    enum DotUnit: String, CaseIterable, Identifiable {
        case auto, day, week, month
        var id: Self { self }
    }

    var title = ""
    var kind: Kind = .countdown
    /// The countdown target or the time-since start. Only the calendar day is used.
    var day: Date
    /// An exact time on [day]; nil means the whole day. Only hour and minute are used.
    var time: Date?
    /// Kept from a calendar event with a fixed zone; the editor never sets one itself.
    var zoneID: String?
    var period: Period = .year
    var rangeStart: Date
    var rangeEnd: Date
    var look: Look = .number
    var dotShape: WidgetContent.Dots.Shape = .circle
    var dotUnit: DotUnit = .auto
    var fillPast = true
    var theme: CardTheme = .tangerine

    init(kind: Kind = .countdown, today: Date = .now, calendar: Calendar = .current) {
        let start = calendar.startOfDay(for: today)
        self.kind = kind
        day = kind == .countdown ? calendar.date(byAdding: .day, value: 30, to: start)! : start
        rangeStart = start
        rangeEnd = calendar.date(byAdding: .month, value: 3, to: start)!
        if kind == .progress { look = .bar }
    }

    static func looks(for kind: Kind) -> [Look] {
        switch kind {
        case .countdown: [.number, .ring, .dots, .bar, .longCat]
        case .timeSince: [.number, .ring, .dots]
        case .progress: [.number, .ring, .dots, .bar, .longCat]
        }
    }

    var looks: [Look] { Self.looks(for: kind) }

    /// Switching kind keeps the style when the new kind has it.
    mutating func setKind(_ newKind: Kind, today: Date = .now, calendar: Calendar = .current) {
        guard newKind != kind else { return }
        let start = calendar.startOfDay(for: today)
        // A countdown looks ahead, a time-since looks back.
        if newKind == .countdown, day <= start { day = calendar.date(byAdding: .day, value: 30, to: start)! }
        if newKind == .timeSince, day > start { day = start }
        kind = newKind
        if !looks.contains(look) { look = .number }
    }

    var isTitleEmpty: Bool { title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Used by the preview while the title is still empty.
    var placeholderTitle: String {
        switch kind {
        case .countdown: "Countdown"
        case .timeSince: "Days since"
        case .progress: "Progress"
        }
    }
}
