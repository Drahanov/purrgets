import SwiftUI

/// First launch: the long cat hangs from the top of the screen. Pull him down and he stretches,
/// counting up the time on his belly (a longer cat is more time, the app's one idea).
/// He grips the Dynamic Island, the notch, or a rod on screens with neither. A real pull
/// (a third of the way or more) and he boings up out of sight; [done] then hands over to Home,
/// where the shelf cat drops in.
struct PullCatOnboarding: View {
    var done: () -> Void

    /// Joe has just leapt up from step one: he drops into view and catches the top.
    init(entrance: Bool = false, done: @escaping () -> Void) {
        self.done = done
        _arrived = State(initialValue: !entrance)
    }

    @State private var arrived: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Extra length pulled, in points; 0 is hanging at rest.
    @State private var pull: CGFloat = 0
    @State private var dragging = false
    /// Where the finger is sideways, relative to the cat: his eyes follow it.
    @State private var look: CGFloat = 0
    /// Lifts the whole cat away once he's let go.
    @State private var flight: CGFloat = 0
    /// A little tumble and speed-stretch while he flies.
    @State private var spin: Double = 0
    @State private var streak: CGFloat = 1
    /// The time shown when he was let go, kept while he flies off.
    @State private var lastLabel: Rig.Label?
    @State private var leaving = false
    @State private var lastTouch = Date.now
    @State private var tugs = 0
    @State private var boings = 0
    /// Set after a pull too small to count: the hint asks for more.
    @State private var further = false
    @State private var screen = CGSize(width: 390, height: 800)
    /// The top safe area, which tells what the phone has up there (island, notch or nothing).
    @State private var safeTop: CGFloat = 0
    private var rig: Rig { Rig(screen: screen, top: Hanger(safeTop: safeTop, width: screen.width)) }

    var body: some View {
        GeometryReader { outer in
            GeometryReader { geo in
                scene(geo)
            }
            .ignoresSafeArea()
            .onAppear { safeTop = outer.safeAreaInsets.top }
            .onChange(of: outer.safeAreaInsets.top) { _, top in safeTop = top }
        }
        .foregroundStyle(Palette.ink)
        .sensoryFeedback(.selection, trigger: Rig.label(for: pullDays).text)
        .sensoryFeedback(.impact(weight: .heavy), trigger: boings)
        .task { await idle() }
    }

    private func scene(_ geo: GeometryProxy) -> some View {
            ZStack(alignment: .top) {
                Palette.paper

                if case .rod(let rod) = rig.top {
                    // Nothing up there to hang from, so he gets a rod.
                    Capsule()
                        .fill(Palette.ink)
                        .frame(width: rod.width, height: rod.height)
                        .offset(y: rod.minY)
                }

                VStack(spacing: 6) {
                    Text("Pull Joe down")
                        .font(.rounded(30, .black))
                    Text("The longer Joe gets, the more time he counts.")
                        .font(.rounded(16, .bold))
                        .foregroundStyle(Palette.ink.opacity(0.6))
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .offset(y: rig.titleY)
                .opacity(leaving || pull > 20 ? 0 : 1)
                .animation(Motion.gentle, value: pull > 20)
                .arrive()

                cat(rig)

                hint(rig)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear {
                screen = geo.size
                if !arrived {
                    // Drops in from his leap and catches the top, with a bit of a bounce.
                    withAnimation(.spring(duration: 0.6, bounce: 0.38).delay(0.05)) { arrived = true }
                }
                #if DEBUG
                // For screenshots: --intro-pull 0.5 shows him pulled halfway.
                let arguments = ProcessInfo.processInfo.arguments
                if let index = arguments.firstIndex(of: "--intro-pull"), index + 1 < arguments.count,
                   let share = Double(arguments[index + 1]) {
                    pull = rig.room * share
                    dragging = true
                    if arguments.contains("--intro-release") {
                        Task {
                            try? await Task.sleep(for: .seconds(1))
                            dragging = false
                            leave(rig, letGo: false)
                        }
                    }
                }
                #endif
            }
            .onChange(of: geo.size) { _, size in screen = size }
            .contentShape(Rectangle())
            .gesture(drag(rig))
            .overlay(alignment: .topTrailing) {
                Button("Skip") { leave(rig, letGo: true) }
                    .font(.rounded(15, .heavy))
                    .foregroundStyle(Palette.ink.opacity(0.5))
                    .padding(.horizontal, 20)
                    .padding(.top, max(safeTop, 20) + 8)
                    .opacity(leaving ? 0 : 1)
            }
    }

    // MARK: - The cat

    private func cat(_ rig: Rig) -> some View {
        let length = rig.rest + pull
        let label = lastLabel ?? Rig.label(for: pullDays)
        let progress = rig.progress(pull)
        return ZStack(alignment: .top) {
            // His eyes are drawn separately, so they can grow as he's stretched.
            CatArt(pose: .hanging, warp: rig.warp(length: length), hidden: [.eyes, .pupils, .highlights], anchor: .top)
                .frame(width: Rig.width, height: length)
            WideEyes(grow: 1 + 0.55 * progress, look: look, pupils: false)
                .fill(.white)
                .frame(width: Rig.width, height: length)
            WideEyes(grow: 1 + 0.55 * progress, look: look, pupils: true)
                .fill(Palette.ink)
                .frame(width: Rig.width, height: length)
        }
        .overlay(alignment: .topLeading) {
            // The time so far, big, alongside his belly.
            VStack(alignment: .leading, spacing: -10) {
                Text(label.number)
                    .font(.rounded(96, .black))
                    .contentTransition(.numericText())
                Text(label.unit)
                    .font(.rounded(26, .heavy))
            }
            .foregroundStyle(Palette.tangerine)
            .fixedSize()
            .offset(x: Rig.width + 14, y: rig.belly(length: length) - 64)
            // Gone the moment he's let go, so it doesn't count back down as he snaps short.
            .opacity(pull > 12 && !leaving ? 1 : 0)
            .animation(Motion.snappy, value: label)
            .animation(leaving ? .easeOut(duration: 0.08) : Motion.gentle, value: pull > 12 && !leaving)
        }
        .frame(width: Rig.width, height: length, alignment: .top)
        .modifier(Tremble(on: dragging && rig.progress(pull) > 0.85 && !reduceMotion))
        .phaseAnimator([-1.5, 1.5], trigger: dragging) { view, sway in
            view.rotationEffect(.degrees(dragging || leaving || reduceMotion ? 0 : sway), anchor: .top)
        } animation: { _ in .easeInOut(duration: 1.6) }
        .keyframeAnimator(initialValue: 0.0, trigger: tugs) { view, tug in
            view.offset(y: tug)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(18, duration: 0.25)
                SpringKeyframe(0, duration: 0.5, spring: .bouncy)
            }
        }
        .scaleEffect(x: 1 / streak, y: streak, anchor: .top)
        .rotationEffect(.degrees(spin))
        .offset(y: rig.hangY + flight + (arrived ? 0 : -(rig.hangY + rig.rest + 60)))
        .accessibilityElement()
        .accessibilityLabel("Mr. Joe Long, hanging from the top of the screen")
        .accessibilityHint("Drag down to stretch him")
    }

    private func hint(_ rig: Rig) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "chevron.compact.down")
                .font(.system(size: 26, weight: .bold))
                .phaseAnimator([0.0, 8.0]) { arrow, y in
                    arrow.offset(y: reduceMotion ? 0 : y)
                } animation: { _ in .easeInOut(duration: 0.7) }
            Text(further ? "Further!" : "Pull me")
                .font(.rounded(17, .heavy))
                .contentTransition(.opacity)
                .animation(Motion.snappy, value: further)
        }
        .foregroundStyle(Palette.ink.opacity(0.55))
        .offset(y: rig.hangY + rig.rest + 18)
        .opacity(pull > 8 || leaving ? 0 : 1)
        .animation(Motion.gentle, value: pull > 8)
    }

    // MARK: - Pulling

    private var pullDays: Int { Rig.days(progress: rig.progress(pull)) }

    private func drag(_ rig: Rig) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !leaving else { return }
                lastTouch = .now
                further = false
                if !dragging {
                    withAnimation(Motion.snappy) { dragging = true }
                }
                // Past the longest he goes, he only gives a little (rubber band).
                let raw = max(value.translation.height, 0)
                pull = raw <= rig.room ? raw : rig.room + (raw - rig.room) * 0.15
                let side = value.location.x - rig.screen.width / 2
                withAnimation(Motion.snappy) { look = min(max(side / 110, -1), 1) }
            }
            .onEnded { _ in
                guard !leaving else { return }
                dragging = false
                // A proper pull launches him; a nudge just boings him back.
                if rig.progress(pull) >= 0.3 {
                    leave(rig, letGo: false)
                } else {
                    if pull > 8 { boings += 1 }
                    further = pull > 8
                    withAnimation(.spring(duration: 0.45, bounce: 0.55)) {
                        pull = 0
                        look = 0
                    }
                }
            }
    }

    /// Off he goes. Let go after a pull, he boings back up and out of sight; skipped or ignored,
    /// he just lets go of the top and drops.
    private func leave(_ rig: Rig, letGo skipped: Bool) {
        guard !leaving else { return }
        lastLabel = Rig.label(for: pullDays)
        leaving = true
        Task {
            if reduceMotion {
                withAnimation(.easeInOut(duration: 0.3)) { flight = -rig.screen.height }
                try? await Task.sleep(for: .seconds(0.3))
            } else if skipped {
                withAnimation(.easeIn(duration: 0.45)) { flight = rig.screen.height }
                try? await Task.sleep(for: .seconds(0.2))
            } else {
                // Like a rubber band: still holding on, his body snaps short and his feet whip up...
                boings += 1
                let power = rig.progress(pull)
                withAnimation(.spring(duration: 0.16, bounce: 0)) {
                    pull = -rig.rest * 0.2
                    look = 0
                }
                try? await Task.sleep(for: .seconds(0.1))
                // ...then he lets go and shoots up, fast from the start, faster the harder you pulled.
                let time = 0.42 - 0.14 * power
                withAnimation(.timingCurve(0.2, 0.75, 0.45, 1, duration: time)) {
                    flight = -(rig.hangY + rig.rest + 80)
                    spin = Bool.random() ? 9 : -9
                }
                withAnimation(.easeOut(duration: time * 0.5)) { streak = 1.18 }
                try? await Task.sleep(for: .seconds(time * 0.85))
            }
            done()
        }
    }

    /// Nobody's pulling: he tugs at himself now and then, to show he can be pulled. He waits as
    /// long as it takes; Skip is there for anyone who doesn't want to play.
    private func idle() async {
        while !Task.isCancelled, !leaving {
            try? await Task.sleep(for: .seconds(3))
            guard !dragging, !leaving, !reduceMotion else { continue }
            if Date.now.timeIntervalSince(lastTouch) > 2.5 { tugs += 1 }
        }
    }
}

/// Sizes and the time scale for the hanging cat on a screen.
private struct Rig {
    var screen: CGSize
    var top: Hanger

    static let width: CGFloat = 58
    /// The drawing's own outline in pose units (it doesn't fill its canvas).
    static let outline: CGRect = {
        var all = Path()
        CatPose.hanging.layers.flatMap(\.1).forEach { all.addPath($0) }
        return all.boundingRect
    }()
    /// Pose units to points.
    static var scale: CGFloat { width / outline.width }
    /// At rest the body is squeezed this much (pose units), so he starts out not too long.
    static let restSqueeze: CGFloat = 300

    /// His paws grip the bottom of whatever he hangs from, overlapping it a little.
    var hangY: CGFloat { top.bottom - 10 }
    var rest: CGFloat { (Self.outline.height - Self.restSqueeze) * Self.scale }
    /// How much longer he can get: nearly to the bottom of the screen.
    var room: CGFloat { max(screen.height - 90 - hangY - rest, 120) }
    var titleY: CGFloat { hangY + rest + 110 }

    func warp(length: CGFloat) -> CatWarp {
        CatWarp(y: CatWarp.hangingZone, stretchY: length / Self.scale - Self.outline.height)
    }

    /// The middle of the stretchy part of the body, where the label rides.
    func belly(length: CGFloat) -> CGFloat {
        let zone = CatWarp.hangingZone
        let extra = length / Self.scale - Self.outline.height
        return ((zone.from + zone.to + extra) / 2 - Self.outline.minY) * Self.scale
    }

    func progress(_ pull: CGFloat) -> Double { Double(min(max(pull / room, 0), 1)) }

    /// 1 day at rest up to 2 years fully stretched, growing faster the further you pull.
    static func days(progress: Double) -> Int {
        max(1, Int(pow(730, progress).rounded()))
    }

    struct Label: Equatable {
        var number: String
        var unit: String
        var text: String { number + " " + unit }
    }

    static func label(for days: Int) -> Label {
        switch days {
        case ..<14: Label(number: "\(days)", unit: days == 1 ? "day" : "days")
        case ..<60: Label(number: "\(days / 7)", unit: "weeks")
        case ..<365: Label(number: "\(days / 30)", unit: days / 30 == 1 ? "month" : "months")
        default: Label(number: "\(days / 365)", unit: days / 365 == 1 ? "year!" : "years!")
        }
    }
}

/// The hanging cat's eyes, grown by [grow] round each eye's middle, in the same frame as the
/// cat (they sit above the stretchy part, so stretching doesn't move them).
private struct WideEyes: Shape {
    var grow: CGFloat
    var look: CGFloat
    /// Draws the pupils instead of the whites.
    var pupils: Bool

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(grow, look) }
        set { (grow, look) = (newValue.first, newValue.second) }
    }

    private static let eyes: [(white: Path, pupils: [Path], middle: CGPoint)] = {
        let pose = CatPose.hanging
        let pupils = pose.paths(.pupils)
        return pose.paths(.eyes).map { white in
            let box = white.boundingRect
            let inside = pupils.filter { box.contains(CGPoint(x: $0.boundingRect.midX, y: $0.boundingRect.midY)) }
            return (white, inside, CGPoint(x: box.midX, y: box.midY))
        }
    }()

    func path(in rect: CGRect) -> Path {
        let scale = rect.width / Rig.outline.width
        let place = CGAffineTransform(translationX: rect.minX, y: rect.minY)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -Rig.outline.minX, y: -Rig.outline.minY)
        var out = Path()
        for eye in Self.eyes {
            let m = eye.middle
            var t = CGAffineTransform(translationX: m.x, y: m.y).scaledBy(x: grow, y: grow).translatedBy(x: -m.x, y: -m.y)
            if pupils {
                t = t.concatenating(CGAffineTransform(translationX: look * CatPose.hanging.lookReach * grow, y: 0))
                eye.pupils.forEach { out.addPath($0, transform: t.concatenating(place)) }
            } else {
                out.addPath(eye.white, transform: t.concatenating(place))
            }
        }
        return out
    }
}

/// What the cat hangs from at the top of the screen. iOS doesn't say where the Dynamic Island
/// or notch is, so it's told apart by the top safe area: about 59 points or more with an island,
/// 44 to 50 with a notch, 20 or less with neither (and on iPad and Mac).
private enum Hanger {
    case island(CGRect)
    case notch(CGRect)
    case rod(CGRect)

    init(safeTop: CGFloat, width: CGFloat) {
        if !Platform.isMac, safeTop >= 51 {
            self = .island(CGRect(x: width / 2 - 63, y: 11, width: 126, height: 37))
        } else if !Platform.isMac, safeTop >= 40 {
            self = .notch(CGRect(x: width / 2 - 81, y: 0, width: 162, height: 31))
        } else {
            self = .rod(CGRect(x: width / 2 - 60, y: max(safeTop, 8) + 14, width: 120, height: 9))
        }
    }

    var bottom: CGFloat {
        switch self {
        case .island(let r), .notch(let r), .rod(let r): r.maxY
        }
    }
}

/// A nervous shiver, for when he's been stretched a very long way.
private struct Tremble: ViewModifier {
    var on: Bool

    func body(content: Content) -> some View {
        content.phaseAnimator([-1.4, 1.4]) { view, x in
            view.offset(x: on ? x : 0)
        } animation: { _ in .linear(duration: 0.035) }
    }
}
