import SharedLogic
import SwiftUI

// The pieces the add-widget walkthrough is drawn with: the devices, the finger and the cursor,
// and the user's own card shrunk to fit. Scenes are pure functions of seconds into a step,
// so a frame is the same every time it plays and can be paused or jumped to.

/// Where the walkthrough is: which step, how far into it, and a free-running clock for wobbles.
struct GuideBeat {
    var step: Int
    var t: Double
    var clock: Double
}

/// Easing on plain numbers, for scenes driven by time.
enum Tween {
    /// 0 before [a], 1 after [b], eased in between.
    static func ramp(_ t: Double, _ a: Double, _ b: Double) -> Double {
        let x = min(max((t - a) / (b - a), 0), 1)
        return x * x * (3 - 2 * x)
    }

    /// Like [ramp], overshooting a little before it settles: things landing.
    static func land(_ t: Double, _ a: Double, _ b: Double) -> Double {
        let x = min(max((t - a) / (b - a), 0), 1)
        let c1 = 1.4, c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }

    /// Fades in at [a] and out at [b].
    static func window(_ t: Double, _ a: Double, _ b: Double, fade: Double = 0.15) -> Double {
        ramp(t, a, a + fade) * (1 - ramp(t, b, b + fade))
    }

    static func mix(_ a: CGFloat, _ b: CGFloat, _ k: Double) -> CGFloat { a + (b - a) * k }

    static func mix(_ a: CGPoint, _ b: CGPoint, _ k: Double) -> CGPoint {
        CGPoint(x: mix(a.x, b.x, k), y: mix(a.y, b.y, k))
    }
}

// MARK: - Finger and cursor

/// One frame of the finger or cursor.
struct Touch {
    var at: CGPoint
    var opacity = 1.0
    var down = false
    /// How far a long press has got, for the ring around the finger.
    var hold = 0.0
    /// 0...1 since the last press began; 0 when there's no ripple.
    var ripple = 0.0
}

/// What the finger or cursor does in one step: where it goes, and when it taps, holds and drags.
struct TouchScript {
    var moves: [(Double, CGPoint)]
    var taps: [Double] = []
    var longPresses: [ClosedRange<Double>] = []
    var drags: [ClosedRange<Double>] = []
    var enter = 0.0
    var leave = 1e9

    func touch(at t: Double) -> Touch {
        var touch = Touch(at: point(at: t))
        touch.opacity = Tween.ramp(t, enter, enter + 0.25) * (1 - Tween.ramp(t, leave, leave + 0.25))
        touch.down = taps.contains { t >= $0 && t < $0 + 0.16 }
            || longPresses.contains { $0.contains(t) } || drags.contains { $0.contains(t) }
        if let press = longPresses.first(where: { $0.contains(t) }) {
            touch.hold = (t - press.lowerBound) / (press.upperBound - press.lowerBound)
        }
        let presses = taps + longPresses.map(\.upperBound) + drags.map(\.lowerBound)
        if let last = presses.filter({ $0 <= t }).max(), t - last < 0.45 {
            touch.ripple = max((t - last) / 0.45, 0.001)
        }
        return touch
    }

    private func point(at t: Double) -> CGPoint {
        guard let first = moves.first else { return .zero }
        if t <= first.0 { return first.1 }
        for (a, b) in zip(moves, moves.dropFirst()) where t < b.0 {
            return Tween.mix(a.1, b.1, Tween.ramp(t, a.0, b.0))
        }
        return moves.last!.1
    }
}

/// A fingertip like the Simulator's touch dot: squishes on a tap, rings round on a long press.
struct Fingertip: View {
    var touch: Touch

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white, lineWidth: 2)
                .frame(width: 28, height: 28)
                .scaleEffect(1 + touch.ripple * 1.3)
                .opacity(touch.ripple > 0 ? 1 - touch.ripple : 0)
            Circle()
                .trim(from: 0, to: touch.hold)
                .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 36, height: 36)
            Circle()
                .fill(.white.opacity(0.75))
                .overlay(Circle().stroke(Palette.ink.opacity(0.3), lineWidth: 1))
                .frame(width: 24, height: 24)
                .scaleEffect(touch.down ? 0.8 : 1)
                .shadow(color: Palette.ink.opacity(0.25), radius: touch.down ? 1 : 4, y: touch.down ? 1 : 3)
        }
        .opacity(touch.opacity)
        .position(touch.at)
        .allowsHitTesting(false)
    }
}

/// The Mac arrow, its tip on the point. A click sends out a ring.
struct Cursor: View {
    var touch: Touch

    var body: some View {
        ZStack(alignment: .topLeading) {
            Circle()
                .stroke(Palette.ink.opacity(0.6), lineWidth: 1.2)
                .frame(width: 14, height: 14)
                .scaleEffect(0.4 + touch.ripple * 1.2)
                .opacity(touch.ripple > 0 ? 1 - touch.ripple : 0)
                .offset(x: -7, y: -7)
            Arrow()
                .fill(.black)
                .overlay(Arrow().stroke(.white, style: StrokeStyle(lineWidth: 0.9, lineJoin: .round)))
                .frame(width: 10, height: 15)
                .scaleEffect(touch.down ? 0.88 : 1, anchor: .topLeading)
                .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
        }
        .frame(width: 0, height: 0, alignment: .topLeading)
        .opacity(touch.opacity)
        .position(touch.at)
        .allowsHitTesting(false)
    }

    private struct Arrow: Shape {
        func path(in rect: CGRect) -> Path {
            let points: [(CGFloat, CGFloat)] = [(0, 0), (0, 13), (3.2, 10), (5.4, 15), (7.3, 14.2), (5.2, 9.4), (9.5, 9.4)]
            return Path { path in
                path.addLines(points.map { CGPoint(x: $0.0 / 9.5 * rect.width, y: $0.1 / 15 * rect.height) })
                path.closeSubpath()
            }
        }
    }
}

// MARK: - Devices

/// An iPhone with a Dynamic Island. The screen is drawn at 200 × 430 points.
struct PhoneFrame<Screen: View>: View {
    static var screen: CGSize { CGSize(width: 200, height: 430) }
    static var size: CGSize { CGSize(width: 214, height: 444) }

    @ViewBuilder var content: Screen

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Palette.ink)
                .shadow(color: Palette.ink.opacity(0.25), radius: 18, y: 10)
            content
                .frame(width: Self.screen.width, height: Self.screen.height)
                .clipShape(RoundedRectangle(cornerRadius: 29, style: .continuous))
            Capsule()
                .fill(.black)
                .frame(width: 58, height: 17)
                .position(x: Self.size.width / 2, y: 20)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(alignment: .leading) {
            VStack(spacing: 8) {
                Capsule().frame(width: 3, height: 22)
                Capsule().frame(width: 3, height: 36)
                Capsule().frame(width: 3, height: 36)
            }
            .foregroundStyle(Palette.ink)
            .offset(x: -2, y: -60)
        }
    }
}

/// A MacBook. The screen is drawn at 400 × 250 points.
struct MacFrame<Screen: View>: View {
    static var screen: CGSize { CGSize(width: 400, height: 250) }
    static var size: CGSize { CGSize(width: 460, height: 284) }

    @ViewBuilder var content: Screen

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14, style: .continuous)
                    .fill(Palette.ink)
                content
                    .frame(width: Self.screen.width, height: Self.screen.height)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 7, topTrailingRadius: 7, style: .continuous))
                    .padding(.top, 8)
                UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 4)
                    .fill(Palette.ink)
                    .frame(width: 44, height: 8)
                    .padding(.top, 8)
            }
            .frame(width: Self.screen.width + 16, height: Self.screen.height + 20)
            ZStack(alignment: .top) {
                UnevenRoundedRectangle(bottomLeadingRadius: 8, bottomTrailingRadius: 8, style: .continuous)
                    .fill(Palette.ink.opacity(0.85))
                UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 4)
                    .fill(Palette.ink.opacity(0.55))
                    .frame(width: 60, height: 4)
            }
            .frame(width: Self.size.width, height: 14)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .shadow(color: Palette.ink.opacity(0.22), radius: 16, y: 10)
    }
}

/// The iPhone status bar.
struct PhoneStatusBar: View {
    var tint: Color = .white

    var body: some View {
        HStack {
            Text("9:41").font(.system(size: 11, weight: .semibold))
            Spacer()
            HStack(spacing: 3) {
                Image(systemName: "cellularbars")
                Image(systemName: "wifi")
                Image(systemName: "battery.100")
            }
            .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 24)
        .frame(width: PhoneFrame<EmptyView>.screen.width)
        .position(x: 100, y: 17)
    }
}

// MARK: - Cards

/// A real widget card at its true size, shrunk into the drawing so it looks exactly like the widget.
struct MiniWidget: View {
    enum Face {
        case tracker(WidgetContent)
        /// What a fresh widget shows before the user picks a tracker.
        case pick
    }

    var face: Face
    var size: CardSize
    var width: CGFloat

    var body: some View {
        let real = size.previewSize
        let scale = width / real.width
        card
            .frame(width: real.width, height: real.height)
            .scaleEffect(scale)
            .frame(width: width, height: real.height * scale)
    }

    @ViewBuilder private var card: some View {
        if size.isAccessory {
            face.view(size)
                .foregroundStyle(.white)
                .environment(\.colorScheme, .dark)
        } else {
            face.view(size)
                .background(face.theme.background)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .paperEdge(face.theme, cornerRadius: 22)
        }
    }
}

private extension MiniWidget.Face {
    @ViewBuilder func view(_ size: CardSize) -> some View {
        switch self {
        case .tracker(let content): TrackerCard(content: content, size: size)
        case .pick: ChooseTrackerCard(reason: .pick, size: size)
        }
    }

    var theme: CardTheme {
        if case .tracker(let content) = self { content.theme } else { .paper }
    }
}

/// A fresh widget turning into the user's tracker once it's picked: [picked] crossfades 0 → 1.
struct PickedWidget: View {
    var content: WidgetContent
    var size: CardSize
    var width: CGFloat
    var picked: Double

    var body: some View {
        ZStack {
            MiniWidget(face: .pick, size: size, width: width).opacity(1 - picked)
            MiniWidget(face: .tracker(content), size: size, width: width)
                .opacity(picked)
                .scaleEffect(1 + 0.08 * sin(picked * .pi))
        }
    }
}

/// The user's newest tracker at every size the guide draws, or the gallery's sample when there's none.
struct GuideCards {
    private var contents: [CardSize: WidgetContent] = [:]
    var title: String

    init(_ make: (CardSize) -> WidgetContent) {
        for size in [CardSize.small, .medium, .circular, .rectangular] { contents[size] = make(size) }
        title = contents[.small]!.title
    }

    static var sample: GuideCards {
        GuideCards { WidgetContent(state: PreviewStates.shared.named(name: "countdown-number", maxDots: $0.maxDots)) }
    }

    subscript(size: CardSize) -> WidgetContent { contents[size] ?? contents[.small]! }
}

/// Our app icon as the system lists it.
struct MiniAppIcon: View {
    var side: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: side * 0.23, style: .continuous)
            .fill(Palette.tangerine)
            .overlay(Image(systemName: "pawprint.fill").font(.system(size: side * 0.5)).foregroundStyle(Palette.ink))
            .frame(width: side, height: side)
    }
}

/// A plain coloured app icon standing in for someone else's app.
struct StandInIcon: View {
    var color: Color
    var side: CGFloat
    var symbol: String?

    var body: some View {
        RoundedRectangle(cornerRadius: side * 0.23, style: .continuous)
            .fill(color)
            .overlay {
                if let symbol { Image(systemName: symbol).font(.system(size: side * 0.48, weight: .semibold)).foregroundStyle(.white) }
            }
            .frame(width: side, height: side)
    }
}
