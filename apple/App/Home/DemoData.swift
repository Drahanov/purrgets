import Foundation

#if DEBUG
/// App Store screenshots: `--demo-data` fills an empty store with these realistic trackers.
enum DemoData {
    static func drafts(today: Date = .now, calendar: Calendar = .current) -> [EditorDraft] {
        let start = calendar.startOfDay(for: today)
        func days(_ n: Int) -> Date { calendar.date(byAdding: .day, value: n, to: start)! }

        var trip = EditorDraft(kind: .countdown, today: today)
        trip.title = "Tokyo trip"
        trip.day = days(23)
        trip.look = .longCat
        trip.theme = .marigold

        var wedding = EditorDraft(kind: .countdown, today: today)
        wedding.title = "Our wedding"
        wedding.day = days(142)
        wedding.theme = .tangerine

        var newYear = EditorDraft(kind: .countdown, today: today)
        newYear.title = "New Year"
        newYear.day = calendar.date(from: DateComponents(year: calendar.component(.year, from: today) + 1, month: 1, day: 1))!
        newYear.look = .dots
        newYear.dotShape = .paw
        newYear.theme = .paper

        var smoke = EditorDraft(kind: .timeSince, today: today)
        smoke.title = "Smoke free"
        smoke.day = days(-87)
        smoke.look = .ring
        smoke.theme = .sand

        var year = EditorDraft(kind: .progress, today: today)
        year.title = "\(calendar.component(.year, from: today))"
        year.period = .year
        year.look = .bar
        year.theme = .tangerine

        var gym = EditorDraft(kind: .timeSince, today: today)
        gym.title = "Last gym day"
        gym.day = days(-3)
        gym.theme = .paper

        var week = EditorDraft(kind: .progress, today: today)
        week.title = "This week"
        week.period = .week
        week.look = .ring
        week.theme = .marigold

        return [trip, wedding, newYear, smoke, year, gym, week]
    }
}
#endif
