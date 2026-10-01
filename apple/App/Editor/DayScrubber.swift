import SwiftUI

/// A ruler of days you drag to pick a date. One tick per day, taller ticks on Mondays and
/// month starts. It ticks under your finger (haptics) and the preview follows live.
struct DayScrubber: View {
    @Binding var day: Date

    private static let span = 3650
    private static let tick: CGFloat = 12
    private let calendar = Calendar.current
    private let today = Calendar.current.startOfDay(for: .now)

    @State private var position: Int?
    @State private var width: CGFloat = 0

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(-Self.span...Self.span, id: \.self) { offset in
                    TickMark(date: date(at: offset), isToday: offset == 0)
                        .frame(width: Self.tick, height: 64)
                        .id(offset)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollPosition(id: $position, anchor: .center)
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.horizontal, max(0, width / 2 - Self.tick / 2), for: .scrollContent)
        .frame(height: 64)
        .overlay(alignment: .top) { needle }
        .mask(
            LinearGradient(
                stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.15),
                        .init(color: .black, location: 0.85), .init(color: .clear, location: 1)],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { width = $0 }
        .onAppear { position = offset(of: day) }
        .onChange(of: position) { _, offset in
            guard let offset else { return }
            let picked = date(at: offset)
            if picked != day { day = picked }
        }
        .onChange(of: day) { _, newDay in
            let offset = offset(of: newDay)
            if offset != position { withAnimation(Motion.gentle) { position = offset } }
        }
        .sensoryFeedback(.selection, trigger: position)
        .sensoryFeedback(.impact(weight: .medium), trigger: month(of: position))
        .accessibilityRepresentation {
            DatePicker("Date", selection: $day, displayedComponents: .date)
        }
    }

    private var needle: some View {
        VStack(spacing: 0) {
            Triangle().fill(Palette.ink).frame(width: 12, height: 7)
            Capsule().fill(Palette.ink).frame(width: 3, height: 34)
        }
        .allowsHitTesting(false)
    }

    private func date(at offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: today)!
    }

    private func offset(of date: Date) -> Int {
        let days = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: date)).day ?? 0
        return min(max(days, -Self.span), Self.span)
    }

    private func month(of offset: Int?) -> Int {
        calendar.component(.month, from: date(at: offset ?? 0))
    }
}

private struct TickMark: View {
    var date: Date
    var isToday: Bool

    var body: some View {
        let calendar = Calendar.current
        let dayOfMonth = calendar.component(.day, from: date)
        let monday = calendar.component(.weekday, from: date) == 2
        let height: CGFloat = dayOfMonth == 1 ? 30 : (monday ? 18 : 10)
        VStack(spacing: 4) {
            Capsule()
                .fill(isToday ? Palette.tangerine : Palette.ink.opacity(dayOfMonth == 1 ? 0.75 : 0.28))
                .frame(width: dayOfMonth == 1 || isToday ? 2.5 : 1.5, height: isToday ? 30 : height)
                .frame(height: 30, alignment: .bottom)
                .padding(.top, 10)
            if dayOfMonth == 1 {
                Text(date, format: calendar.component(.month, from: date) == 1 ? .dateTime.year() : .dateTime.month(.abbreviated))
                    .font(.rounded(11, .heavy))
                    .foregroundStyle(Palette.ink.opacity(0.6))
                    .fixedSize()
            } else if isToday {
                Text("Today")
                    .font(.rounded(10, .heavy))
                    .foregroundStyle(Palette.tangerine)
                    .fixedSize()
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
