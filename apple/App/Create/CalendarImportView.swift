import SharedLogic
import SwiftUI

/// Upcoming calendar events, grouped by month. Tap one to make it a countdown.
struct CalendarImportView: View {
    var pick: (EditorDraft) -> Void
    @Environment(TrackerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var result: CalendarEventsResult?

    var body: some View {
        NavigationStack {
            Group {
                switch result {
                case nil:
                    VStack(spacing: 14) {
                        BlinkingCat(size: 54)
                        Text("Looking at your calendar…").font(.rounded(15, .heavy)).opacity(0.6)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .events(let events) where events.isEmpty:
                    message(title: "No upcoming events", text: "Nothing on your calendar for the next year.", settings: false)
                case .events(let events):
                    list(events)
                case .noAccess:
                    message(title: "Purrgets can't see your calendar", text: "Allow calendar access in Settings to turn events into countdowns.", settings: true)
                case .unavailable:
                    message(title: "No calendar here", text: "This device has no calendar to import from.", settings: false)
                }
            }
            .foregroundStyle(Palette.ink)
            .background(Palette.paper.ignoresSafeArea())
            .navigationTitle("Import event")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                }
            }
        }
        .tint(Palette.ink)
        .frame(minWidth: Platform.isMac ? 480 : nil, minHeight: Platform.isMac ? 560 : nil)
        .task {
            let loaded = await store.calendarEvents()
            withAnimation(Motion.gentle) { result = loaded }
        }
    }

    private func list(_ events: [CalendarEvent]) -> some View {
        let months = Dictionary(grouping: events.enumerated()) { Self.monthStart(of: $0.element) }
            .sorted { $0.key < $1.key }
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 10, pinnedViews: .sectionHeaders) {
                ForEach(months, id: \.key) { month, rows in
                    Section {
                        ForEach(rows, id: \.element.id) { index, event in
                            EventRow(event: event, index: index) { pick(store.draft(from: event)) }
                                .arrive(index)
                        }
                    } header: {
                        Text(month, format: .dateTime.month(.wide).year())
                            .font(.rounded(13, .heavy))
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .opacity(0.5)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.paper)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
    }

    private func message(title: String, text: String, settings: Bool) -> some View {
        VStack(spacing: 14) {
            SleepingCat(size: 110)
            Text(title).font(.rounded(20, .black)).multilineTextAlignment(.center)
            Text(text).font(.rounded(15, .bold)).opacity(0.6).multilineTextAlignment(.center)
            if settings {
                InkButton(title: "Open Settings", systemImage: "gearshape.fill", action: Platform.openCalendarSettings)
                    .frame(maxWidth: 260)
                    .padding(.top, 6)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .arrive()
    }

    private static func monthStart(of event: CalendarEvent) -> Date {
        let day = event.moment.date.swiftDate
        return Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: day))!
    }
}

private struct EventRow: View {
    var event: CalendarEvent
    var index: Int
    var action: () -> Void

    var body: some View {
        let day = event.moment.date.swiftDate
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(spacing: -2) {
                    Text(day, format: .dateTime.weekday(.abbreviated))
                        .font(.rounded(11, .heavy))
                        .textCase(.uppercase)
                    Text(day, format: .dateTime.day())
                        .font(.rounded(24, .black))
                }
                .frame(width: 54, height: 54)
                .background(CardTheme.allCases[index % 3].background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title).font(.rounded(16, .heavy)).lineLimit(1)
                    Text("\(event.calendar) · \(Self.relative(day))")
                        .font(.rounded(13, .bold))
                        .opacity(0.55)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).opacity(0.35)
            }
            .padding(10)
            .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(SquishStyle(scale: 0.97))
    }

    private static func relative(_ day: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: day).day ?? 0
        switch days {
        case ...0: return "today"
        case 1: return "tomorrow"
        default: return "in \(days) days"
        }
    }
}
