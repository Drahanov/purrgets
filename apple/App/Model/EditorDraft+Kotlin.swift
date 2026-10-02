import Foundation
import SharedLogic

// EditorDraft <-> Kotlin model. Kotlin sealed types arrive as classes, so we match by casting.

typealias LocalDate = Kotlinx_datetimeLocalDate
typealias LocalTime = Kotlinx_datetimeLocalTime
typealias KotlinTimeZone = Kotlinx_datetimeTimeZone

extension EditorDraft {

    init(tracker: Tracker) {
        self.init(title: tracker.title, kind: tracker.kind, theme: tracker.appearance.theme)
    }

    init(draft: TrackerDraft) {
        self.init(title: draft.title, kind: draft.kind, theme: draft.appearance.theme)
    }

    private init(title: String, kind: TrackerKind, theme: Theme) {
        self.init()
        self.title = title
        self.theme = CardTheme(theme)
        switch kind {
        case let countdown as TrackerKindCountdown:
            self.kind = .countdown
            setMoment(countdown.target)
            setStyle(countdown.style)
        case let since as TrackerKindTimeSince:
            self.kind = .timeSince
            setMoment(since.start)
            setStyle(since.style)
        case let progress as TrackerKindProgress:
            self.kind = .progress
            switch progress.range {
            case is ProgressRangeYear: period = .year
            case is ProgressRangeMonth: period = .month
            case is ProgressRangeWeek: period = .week
            case let custom as ProgressRangeCustom:
                period = .custom
                rangeStart = custom.start.date.swiftDate
                rangeEnd = custom.end.date.swiftDate
            default: break
            }
            setStyle(progress.style)
        default:
            break
        }
    }

    // MARK: To Kotlin

    var kotlinKind: TrackerKind {
        switch kind {
        case .countdown:
            return TrackerKindCountdown(target: moment, style: countdownStyle)
        case .timeSince:
            return TrackerKindTimeSince(start: moment, style: timeSinceStyle)
        case .progress:
            return TrackerKindProgress(range: kotlinRange, style: progressStyle)
        }
    }

    var appearance: Appearance { Appearance(theme: theme.kotlin) }

    /// A tracker for the live preview. The title falls back to a placeholder, and a custom range
    /// that ends before it starts is drawn as one day, so the preview never breaks mid-edit.
    func previewTracker(id: String, now: Date = .now) -> Tracker {
        var safe = self
        if safe.rangeEnd < safe.rangeStart { safe.rangeEnd = safe.rangeStart }
        let instant = KotlinInstant.from(now)
        return Tracker(
            id: id, title: isTitleEmpty ? placeholderTitle : title, kind: safe.kotlinKind,
            appearance: appearance, createdAt: instant, updatedAt: instant
        )
    }

    private var moment: Moment {
        let time = self.time.map { date -> LocalTime in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            return LocalTime(hour: Int32(parts.hour ?? 0), minute: Int32(parts.minute ?? 0), second: 0, nanosecond: 0)
        }
        // A fixed zone needs an exact time (the Kotlin model checks this).
        let zone = time == nil ? nil : zoneID.map { KotlinTimeZone.companion.of(zoneId: $0) }
        return Moment(date: day.localDate, time: time, zone: zone)
    }

    private var kotlinRange: ProgressRange {
        switch period {
        case .year: ProgressRangeYear.shared
        case .month: ProgressRangeMonth.shared
        case .week: ProgressRangeWeek.shared
        case .custom: ProgressRangeCustom(start: Moment(date: rangeStart.localDate, time: nil, zone: nil),
                                          end: Moment(date: rangeEnd.localDate, time: nil, zone: nil))
        }
    }

    private var dotOptions: DotOptions {
        let unit: SharedLogic.DotUnit = switch dotUnit {
        case .auto: .auto_
        case .day: .day
        case .week: .week
        case .month: .month
        }
        let shape: DotShape = switch dotShape {
        case .circle: .circle
        case .square: .square
        case .paw: .paw
        }
        return DotOptions(unit: unit, shape: shape, fillPast: fillPast)
    }

    private var countdownStyle: CountdownStyle {
        switch look {
        case .ring: CountdownStyleRing.shared
        case .dots: CountdownStyleDots(options: dotOptions)
        case .bar: CountdownStyleLinear(cat: false)
        case .longCat: CountdownStyleLinear(cat: true)
        default: CountdownStyleNumber.shared
        }
    }

    private var timeSinceStyle: TimeSinceStyle {
        switch look {
        case .ring: TimeSinceStyleRing.shared
        case .dots: TimeSinceStyleDots(options: dotOptions)
        default: TimeSinceStyleNumber.shared
        }
    }

    private var progressStyle: ProgressStyle {
        switch look {
        case .ring: ProgressStyleRing.shared
        case .dots: ProgressStyleDots(options: dotOptions)
        case .bar: ProgressStyleLinear(cat: false)
        case .longCat: ProgressStyleLinear(cat: true)
        default: ProgressStyleNumber.shared
        }
    }

    // MARK: From Kotlin

    private mutating func setMoment(_ moment: Moment) {
        day = moment.date.swiftDate
        zoneID = moment.zoneId
        time = moment.time.flatMap { time in
            Calendar.current.date(bySettingHour: Int(time.hour), minute: Int(time.minute), second: 0, of: day)
        }
    }

    private mutating func setStyle(_ style: Any) {
        switch style {
        case is CountdownStyleRing, is TimeSinceStyleRing, is ProgressStyleRing:
            look = .ring
        case let dots as CountdownStyleDots: setDots(dots.options)
        case let dots as TimeSinceStyleDots: setDots(dots.options)
        case let dots as ProgressStyleDots: setDots(dots.options)
        case let linear as CountdownStyleLinear: look = linear.cat ? .longCat : .bar
        case let linear as ProgressStyleLinear: look = linear.cat ? .longCat : .bar
        default: look = .number
        }
    }

    private mutating func setDots(_ options: DotOptions) {
        look = .dots
        fillPast = options.fillPast
        dotShape = switch options.shape {
        case .square: .square
        case .paw: .paw
        default: .circle
        }
        dotUnit = switch options.unit {
        case .day: .day
        case .week: .week
        case .month: .month
        default: .auto
        }
    }
}

// MARK: - Small conversions

extension Date {
    /// The calendar day of this date on this device.
    var localDate: LocalDate {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: self)
        return LocalDate(year: Int32(parts.year!), month: Int32(parts.month!), day: Int32(parts.day!))
    }
}

extension LocalDate {
    /// Midnight of this day on this device.
    var swiftDate: Date {
        Calendar.current.date(from: DateComponents(year: Int(year), month: Int(month.ordinal) + 1, day: Int(day)))!
    }
}

extension KotlinInstant {
    static func from(_ date: Date) -> KotlinInstant {
        KotlinInstant.companion.fromEpochMilliseconds(epochMilliseconds: Int64(date.timeIntervalSince1970 * 1000))
    }
}

extension CardTheme {
    var kotlin: Theme {
        switch self {
        case .tangerine: .tangerine
        case .marigold: .marigold
        case .sand: .sand
        case .paper: .paper
        }
    }
}

/// Clock.System isn't visible from Swift, so the app hands Kotlin its own.
final class SystemClock: KotlinClock {
    func now() -> KotlinInstant { .from(.now) }
}
