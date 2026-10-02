import SwiftUI

/// A tracker card in the app: the widget's own view, brought to life.
/// Rings, bars, dots and cats fill up when it appears, digits roll when the value changes,
/// and style or colour changes morph instead of jumping. It takes whatever frame it's given.
struct LiveCard: View {
    var content: WidgetContent
    var size: CardSize
    /// Position in a list, so cards fill one after another.
    var index = 0
    var cornerRadius: CGFloat = 22

    @State private var reveal = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        card
            .motion(Motion.gentle, value: content)
            .onAppear {
                if reduceMotion { reveal = 1; return }
                withAnimation(Motion.fill.delay(0.12 + Motion.stagger(index, step: 0.08))) { reveal = 1 }
            }
    }

    @ViewBuilder private var card: some View {
        if size.isAccessory {
            // As the system draws them: a soft disc behind circular widgets, nothing behind the rest.
            TrackerCard(content: content.revealed(reveal), size: size)
                .foregroundStyle(.white)
                .background {
                    if size == .circular { Circle().fill(.white.opacity(0.14)) }
                }
                .environment(\.colorScheme, .dark)
        } else {
            TrackerCard(content: content.revealed(reveal), size: size)
                .background(content.theme.background)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .contextMenuShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

extension WidgetContent {
    /// The card part-way through filling up: 0 is empty, 1 is the real state.
    func revealed(_ t: Double) -> WidgetContent {
        guard t < 1 else { return self }
        var copy = self
        copy.fraction = fraction * t
        switch style {
        case .dots(var dots):
            // "Nothing filled yet" is elapsed 0 for past-filled grids, all of them for future-filled.
            dots.elapsed = dots.fillPast
                ? Int((Double(dots.elapsed) * t).rounded())
                : dots.total - Int((Double(dots.total - dots.elapsed) * t).rounded())
            copy.style = .dots(dots)
        default:
            break
        }
        return copy
    }

    /// Long cats, bars and dot grids get a wide card on Home; the rest a square one.
    var homeSize: CardSize {
        switch style {
        case .longCat, .bar: .medium
        case .dots(let dots): dots.total > 60 ? .medium : .small
        default: .small
        }
    }
}
