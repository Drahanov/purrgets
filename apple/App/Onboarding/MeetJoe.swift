import SharedLogic
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Intro, step one, told one thing at a time: what the app makes (widgets, which pile up one by
/// one), then who lives here (Mr. Joe Long drops onto the pile and falls asleep), then what to do
/// (shake him off). Shaken, he wakes with a start and leaps up out of sight; [leapt] moves on.
struct MeetJoe: View {
    var leapt: () -> Void
    var skip: () -> Void

    @Environment(TrackerStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far the scene has got: cards piled so far, Joe on top, his introduction shown.
    @State private var cardsIn = 0
    @State private var joeIn = false
    @State private var joeIntroduced = false

    @State private var awake = false
    /// Joe's jump: a startled hop, then up and away.
    @State private var lift: CGFloat = 0
    @State private var tilt: Double = 0
    @State private var jolts = 0
    @State private var hops = 0
    /// The pile fades once Joe has leapt off it.
    @State private var pileGone = false

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    Text("Your dates, as widgets")
                        .font(.rounded(32, .black))
                    Text("Countdowns, progress and days since, right on your Home Screen.")
                        .font(.rounded(16, .bold))
                        .foregroundStyle(Palette.ink.opacity(0.6))
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.top, 36)
                .opacity(awake ? 0 : 1)
                .arrive()

                Spacer(minLength: 12)

                pile
                    .frame(height: 300)

                Spacer(minLength: 12)

                VStack(spacing: 8) {
                    Text("Meet Mr. Joe Long")
                        .font(.rounded(22, .black))
                    Text("He lives here, and now and then he wanders into your widgets. Try not to pay him attention. He can tell.")
                        .font(.rounded(15, .bold))
                        .foregroundStyle(Palette.ink.opacity(0.6))
                        .padding(.horizontal, 30)
                    shakeButton
                        .padding(.top, 8)
                }
                .multilineTextAlignment(.center)
                .opacity(joeIntroduced && !awake ? 1 : 0)
                .offset(y: joeIntroduced ? 0 : 16)
                .padding(.bottom, 36)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .foregroundStyle(Palette.ink)
        .overlay(alignment: .topTrailing) {
            Button("Skip", action: skip)
                .font(.rounded(15, .heavy))
                .foregroundStyle(Palette.ink.opacity(0.5))
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .opacity(awake ? 0 : 1)
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: jolts)
        .onShake { shakeOff() }
        .task { await tellTheStory() }
    }

    /// One thing at a time: the cards pile up, Joe drops onto them, then he's introduced.
    private func tellTheStory() async {
        if reduceMotion {
            cardsIn = Pile.cards.count
            joeIn = true
            joeIntroduced = true
            return
        }
        try? await Task.sleep(for: .seconds(0.5))
        for count in 1...Pile.cards.count {
            withAnimation(.spring(duration: 0.45, bounce: 0.3)) { cardsIn = count }
            try? await Task.sleep(for: .seconds(0.2))
        }
        try? await Task.sleep(for: .seconds(0.35))
        // Thud: in he drops, onto the top card.
        withAnimation(.easeIn(duration: 0.26)) { joeIn = true }
        try? await Task.sleep(for: .seconds(0.26))
        jolts += 1
        try? await Task.sleep(for: .seconds(0.6))
        withAnimation(.spring(duration: 0.5, bounce: 0.2)) { joeIntroduced = true }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--intro-shake") {
            try? await Task.sleep(for: .seconds(1))
            shakeOff()
        }
        #endif
    }

    // MARK: - The pile

    /// Widget cards of different kinds, piled up. Joe lies across the top two: belly on one,
    /// head on the other, legs and tail hanging down.
    private var pile: some View {
        ZStack {
            ForEach(Array(Pile.cards.enumerated()), id: \.offset) { order, spot in
                if spot.behindJoe {
                    placed(spot, order: order)
                }
            }
            // His far back leg hangs behind the card he lies on; the rest of him is in front.
            moving(JoeShape(paths: Joe.farLeg).fill(Palette.ink).frame(width: Joe.size.width, height: Joe.size.height))
                .offset(Joe.offset)
            ForEach(Array(Pile.cards.enumerated()), id: \.offset) { order, spot in
                if !spot.behindJoe {
                    placed(spot, order: order)
                }
            }
            moving(joe)
                .offset(Joe.offset)
        }
        .offset(x: -14, y: -24)
    }

    @ViewBuilder private func placed(_ spot: Pile.Spot, order: Int) -> some View {
        if let template = store.templates.first(where: { $0.id == spot.template }) {
            let shown = order < cardsIn
            card(template, size: spot.size, order: order)
                .rotationEffect(.degrees(spot.turn))
                .offset(x: spot.x, y: spot.y + (shown ? 0 : -50))
                .opacity(shown && !pileGone ? 1 : 0)
        }
    }

    private func card(_ template: Template, size: CGFloat, order: Int) -> some View {
        var content = store.content(for: EditorDraft(draft: template.draft), id: template.id, size: .small)
        // Joe is the only cat here: no cameos on the pile.
        content.cameo = nil
        return LiveCard(content: content, size: .small, index: order)
            .frame(width: size, height: size)
            .shadow(color: Palette.ink.opacity(0.08), radius: 6, y: 3)
            .keyframeAnimator(initialValue: CGSize.zero, trigger: jolts) { card, shove in
                card.offset(shove)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(CGSize(width: order.isMultiple(of: 2) ? -10 : 10, height: 8), duration: 0.07)
                    CubicKeyframe(CGSize(width: order.isMultiple(of: 2) ? 6 : -6, height: -3), duration: 0.08)
                    SpringKeyframe(.zero, duration: 0.4, spring: .bouncy)
                }
            }
    }

    private var joe: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Joe.layers.indices, id: \.self) { index in
                let layer = Joe.layers[index]
                if !(awake && layer.0 == .eyes) {
                    JoeShape(paths: layer.1).fill(layer.0.color)
                }
            }
            // Woken: his eyes pop wide open.
            ForEach(Joe.eyes.indices, id: \.self) { index in
                ZStack {
                    Circle().fill(.white)
                    Circle().fill(Palette.ink).padding(Joe.eyeSize * 0.3)
                }
                .frame(width: Joe.eyeSize, height: Joe.eyeSize)
                .scaleEffect(awake ? 1 : 0.1)
                .opacity(awake ? 1 : 0)
                .position(Joe.eyes[index])
            }
            if joeIn, !awake {
                Snore(size: 24)
                    .position(Joe.snore)
                    .transition(.opacity)
            }
        }
        .frame(width: Joe.size.width, height: Joe.size.height)
        .accessibilityElement()
        .accessibilityLabel("Mr. Joe Long, a long black cat, asleep on a pile of widgets")
    }

    /// Joe's arrival, breathing, startled hop and leap, applied alike to both his parts.
    private func moving(_ part: some View) -> some View {
        TimelineView(.animation(paused: awake || reduceMotion)) { context in
            // Slow, deep breaths, one every 3.6 s: he swells up from the belly.
            let t = context.date.timeIntervalSinceReferenceDate
            let breath = awake || reduceMotion ? 0 : (1 - cos(t * 2 * .pi / 3.6)) / 2
            part.scaleEffect(x: 1 + breath * 0.012, y: 1 + breath * 0.06, anchor: Joe.belly)
        }
            .keyframeAnimator(initialValue: HopFrame(), trigger: hops) { view, frame in
                view
                    .scaleEffect(x: frame.stretch, y: 1 / frame.stretch, anchor: .bottom)
                    .offset(y: frame.lift)
            } keyframes: { _ in
                KeyframeTrack(\.lift) {
                    CubicKeyframe(0, duration: 0.05)
                    CubicKeyframe(-34, duration: 0.16)
                    SpringKeyframe(0, duration: 0.22, spring: .snappy)
                }
                KeyframeTrack(\.stretch) {
                    CubicKeyframe(0.9, duration: 0.05)
                    CubicKeyframe(1.05, duration: 0.16)
                    SpringKeyframe(0.95, duration: 0.22, spring: .snappy)
                }
            }
            .rotationEffect(.degrees(tilt))
            .offset(y: lift + (joeIn ? 0 : -320))
            .opacity(joeIn ? 1 : 0)
    }

    private var shakeButton: some View {
        Button { shakeOff() } label: {
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    if !Platform.isMac {
                        Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                            .font(.system(size: 20, weight: .bold))
                            .phaseAnimator([-8.0, 8.0]) { icon, angle in
                                icon.rotationEffect(.degrees(reduceMotion ? 0 : angle))
                            } animation: { _ in .easeInOut(duration: 0.18).delay(0.6) }
                    }
                    Text(Platform.isMac ? "Wake him up" : "Shake him off")
                        .font(.rounded(18, .black))
                }
                .foregroundStyle(Palette.paper)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Palette.ink, in: Capsule())
                if !Platform.isMac {
                    Text("or tap here")
                        .font(.rounded(13, .bold))
                        .foregroundStyle(Palette.ink.opacity(0.45))
                }
            }
        }
        .buttonStyle(SquishStyle())
        .disabled(!joeIntroduced)
    }

    // MARK: - Shaken

    private func shakeOff() {
        guard joeIntroduced, !awake else { return }
        jolts += 1
        withAnimation(Motion.snappy) { awake = true }
        Task {
            if reduceMotion {
                try? await Task.sleep(for: .seconds(0.3))
                leapt()
                return
            }
            // A startled hop...
            try? await Task.sleep(for: .seconds(0.1))
            hops += 1
            try? await Task.sleep(for: .seconds(0.45))
            // ...then straight up and away, to grab whatever's at the top of the screen.
            withAnimation(.timingCurve(0.5, 0, 0.85, 0.6, duration: 0.34)) {
                lift = -900
                tilt = -8
            }
            withAnimation(.easeOut(duration: 0.25)) { pileGone = true }
            try? await Task.sleep(for: .seconds(0.26))
            leapt()
        }
    }
}

/// Z's floating up from a sleeper, one after another, on a clock (so they always run).
private struct Snore: View {
    var size: CGFloat

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    // Each z takes 2.7 s to rise and fade; they start a third apart.
                    let phase = (t / 2.7 + Double(index) / 3).truncatingRemainder(dividingBy: 1)
                    Text("z")
                        .font(.rounded(size * (0.7 + 0.5 * phase), .heavy))
                        .foregroundStyle(Palette.ink.opacity(phase < 0.2 ? phase * 5 : (1 - phase) * 1.25))
                        .offset(x: phase * size * 0.9 + sin(phase * 6) * 3, y: -phase * size * 2.6)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// The cards in the pile, in the order they drop in (bottom ones first). None has a cat in it:
/// Joe is the cat here.
private enum Pile {
    struct Spot {
        var template: String
        var size: CGFloat
        var x: CGFloat
        var y: CGFloat
        var turn: Double
        /// Under Joe's far back leg (everything below and beside the top two).
        var behindJoe: Bool
    }

    static let cards: [Spot] = [
        Spot(template: "month", size: 128, x: -82, y: 98, turn: -8, behindJoe: true),
        Spot(template: "days-since", size: 128, x: 76, y: 112, turn: 7, behindJoe: true),
        // His pillow: a ring card under his head, a little lower than his bed.
        Spot(template: "week", size: 122, x: Joe.headX, y: -2, turn: 5, behindJoe: true),
        // His bed: the number card his belly lies on.
        Spot(template: "new-year", size: Joe.bed, x: 0, y: 0, turn: 0, behindJoe: false),
    ]
}

/// Where things are in the sleeping drawing (concept/cats/source/sleeps-cat.svg, intro_gen.py).
private enum Joe {
    static let layers: [(CatLayer, [Path])] = CatPose.joeAsleep.layers
    static let farLeg: [Path] = CatPose.joeFarLeg.paths(.body)
    /// Both drawings' outline, in their shared units.
    static let box: CGRect = {
        var all = Path()
        (layers.flatMap(\.1) + farLeg).forEach { all.addPath($0) }
        return all.boundingRect
    }()
    /// His belly is flat between his legs along y 345, from x 470 to 812.
    static let gap = (from: CGFloat(470), to: CGFloat(812), y: CGFloat(345))
    /// The card he lies on, wider than the gap so he isn't too big for it.
    static let bed: CGFloat = 136
    static let scale: CGFloat = bed / 1.6 / (gap.to - gap.from)
    static var size: CGSize { CGSize(width: box.width * scale, height: box.height * scale) }
    /// Moves Joe's middle so his belly lies on the bed card (centred, top edge at -bed / 2).
    static var offset: CGSize {
        CGSize(width: (box.midX - (gap.from + gap.to) / 2) * scale, height: -bed / 2 + (box.midY - gap.y) * scale)
    }
    /// How far right of the bed's middle his head is: the pillow card goes under it.
    static var headX: CGFloat { (1075 - (gap.from + gap.to) / 2) * scale + 18 }
    /// He breathes from here, his belly.
    static var belly: UnitPoint { UnitPoint(x: 0.5, y: (gap.y - box.minY) / box.height) }
    /// Just above his head, where the z's float up from.
    static var snore: CGPoint { point(1090, 170) }
    /// The middles of his closed eyes, for the open ones.
    static var eyes: [CGPoint] { [point(998, 257), point(1041, 307)] }
    static var eyeSize: CGFloat { 44 * scale }

    /// A point of the drawing, in points within Joe's frame.
    static func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: (x - box.minX) * scale, y: (y - box.minY) * scale)
    }
}

/// Part of Joe, placed in his frame the same way as every other part.
private struct JoeShape: Shape {
    var paths: [Path]

    func path(in rect: CGRect) -> Path {
        let scale = rect.width / Joe.box.width
        let place = CGAffineTransform(translationX: rect.minX, y: rect.minY)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -Joe.box.minX, y: -Joe.box.minY)
        var out = Path()
        paths.forEach { out.addPath($0, transform: place) }
        return out
    }
}

// MARK: - Shake

#if os(iOS)
extension UIWindow {
    /// Passes the system's shake gesture on to SwiftUI (see onShake).
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}
#endif

extension View {
    /// Runs [action] when the phone is shaken. Does nothing on the Mac.
    func onShake(perform action: @escaping () -> Void) -> some View {
        #if os(iOS)
        onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in action() }
        #else
        self
        #endif
    }
}
