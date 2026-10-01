import Foundation
import SharedLogic

extension WidgetContent {

    init(state: TrackerState) {
        let tracker = state.tracker
        let theme = CardTheme(tracker.appearance.theme)
        let style = Self.style(of: tracker.kind, state: state)
        let cameo = state.cameo.map(Cameo.init)

        if let value = (state.value as? TrackerValueCountdown)?.value {
            let target = value.target.date
            let day = Self.day.string(from: target)
            let exactTime = (tracker.kind as? TrackerKindCountdown)?.target.time != nil
            switch value.status {
            case .passed:
                self.init(tracker.title, theme, "\(value.daysPassed)", Self.days(value.daysPassed) + " ago", "since \(day)", value.fraction, style, cameo)
            case .today:
                let caption = exactTime ? "at \(Self.time.string(from: target))" : "It's the day!"
                self.init(tracker.title, theme, "Today", "", caption, value.fraction, style, cameo)
                if exactTime { countdownTarget = target }
            case .tomorrow:
                self.init(tracker.title, theme, "1", "day", "Tomorrow!", value.fraction, style, cameo)
            default:
                self.init(tracker.title, theme, "\(value.daysLeft)", Self.days(value.daysLeft), "until \(day)", value.fraction, style, cameo)
            }
        } else if let value = (state.value as? TrackerValueTimeSince)?.value {
            let period = value.period
            let caption = period.years > 0 || period.months > 0
                ? Self.period(years: period.years, months: period.months, days: period.days)
                : "next: \(Self.milestone(value.nextMilestone))"
            self.init(tracker.title, theme, "\(value.days)", Self.days(value.days), caption, value.fraction, style, cameo)
        } else {
            let value = (state.value as! TrackerValueProgress).value
            let caption = Self.rangeCaption((tracker.kind as? TrackerKindProgress)?.range, end: value.bounds.end.date)
            self.init(tracker.title, theme, "\(value.percent)", "%", caption, value.fraction, style, cameo)
        }
    }

    private init(
        _ title: String, _ theme: CardTheme, _ value: String, _ unit: String, _ caption: String,
        _ fraction: Double, _ style: Style, _ cameo: Cameo?
    ) {
        let inlineValue = unit.isEmpty ? value : (unit == "%" ? "\(value)%" : "\(value) \(unit)")
        self.init(
            title: title, theme: theme, value: value, unit: unit, caption: caption,
            fraction: fraction, style: style, cameo: cameo, countdownTarget: nil,
            inline: "\(title) · \(inlineValue)"
        )
    }

    private static func style(of kind: TrackerKind, state: TrackerState) -> Style {
        let dots = state.dots.map { grid in
            Dots(
                total: Int(grid.total), elapsed: Int(grid.elapsed), fillPast: grid.fillPast,
                shape: .circle
            )
        }
        func withShape(_ options: DotOptions) -> Style {
            guard var dots else { return .number }
            dots.shape = Dots.Shape(options.shape)
            return .dots(dots)
        }
        // Kotlin sealed types arrive as classes, so we match by casting.
        let style: Any = (kind as? TrackerKindCountdown)?.style
            ?? (kind as? TrackerKindTimeSince)?.style
            ?? (kind as! TrackerKindProgress).style
        switch style {
        case is CountdownStyleRing, is TimeSinceStyleRing, is ProgressStyleRing:
            return .ring
        case let dots as CountdownStyleDots:
            return withShape(dots.options)
        case let dots as TimeSinceStyleDots:
            return withShape(dots.options)
        case let dots as ProgressStyleDots:
            return withShape(dots.options)
        case let linear as CountdownStyleLinear:
            return linear.cat ? .longCat : .bar
        case let linear as ProgressStyleLinear:
            return linear.cat ? .longCat : .bar
        case is TimeSinceStyleFatCat:
            return .fatCat(growth: (state.value as? TrackerValueTimeSince)?.value.fatCatGrowth ?? 0)
        default:
            return .number
        }
    }

    // MARK: Text

    private static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter
    }()

    private static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private static let month: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter
    }()

    private static func days(_ count: Int32) -> String { count == 1 ? "day" : "days" }

    private static func period(years: Int32, months: Int32, days: Int32) -> String {
        [(years, "y"), (months, "m"), (days, "d")]
            .filter { $0.0 > 0 }
            .map { "\($0.0)\($0.1)" }
            .joined(separator: " ")
    }

    private static func milestone(_ milestone: Milestone) -> String {
        switch milestone {
        case let days as MilestoneDays: "\(days.count) days"
        case let years as MilestoneYears: years.count == 1 ? "1 year" : "\(years.count) years"
        default: ""
        }
    }

    private static func rangeCaption(_ range: ProgressRange?, end: Date) -> String {
        guard let range else { return "" }
        let last = end.addingTimeInterval(-1)
        switch range {
        case is ProgressRangeYear: return "of \(Calendar.current.component(.year, from: last))"
        case is ProgressRangeMonth: return "of \(month.string(from: last))"
        case is ProgressRangeWeek: return "of this week"
        default: return "until \(day.string(from: last))"
        }
    }
}

extension CardTheme {
    init(_ theme: Theme) {
        switch theme {
        case .marigold: self = .marigold
        case .sand: self = .sand
        case .paper: self = .paper
        default: self = .tangerine
        }
    }
}

private extension WidgetContent.Dots.Shape {
    init(_ shape: DotShape) {
        switch shape {
        case .square: self = .square
        case .paw: self = .paw
        default: self = .circle
        }
    }
}

private extension WidgetContent.Cameo {
    init(_ cameo: SharedLogic.Cameo) {
        let poses: [CameoPose: Pose] = [.peek: .peek, .paws: .paws, .ears: .ears, .tail: .tail, .sleep: .sleep]
        self.init(cat: cameo.cat == .fat ? .fat : .long, pose: poses[cameo.pose] ?? .peek)
    }
}
