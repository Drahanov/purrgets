import SwiftUI

/// iPhone Lock Screen: hold → Customize → Lock Screen, tap the box under the clock, add a Purrgets widget,
/// then tap it to pick the tracker and tap Done. Drawn on a 200 × 430 screen.
struct LockScreenScene: View {
    var beat: GuideBeat
    var cards: GuideCards

    /// The widget box under the clock, and where our widget sits in it.
    private static let box = CGRect(x: 30, y: 150, width: 140, height: 36)
    private static let slot = CGPoint(x: 66, y: 168)
    private static let slotWidth: CGFloat = 70

    var body: some View {
        let s = LockState(beat)
        ZStack {
            Color(white: 0.12)
            face(s)
                .clipShape(RoundedRectangle(cornerRadius: 29 * s.gallery + 0.01, style: .continuous))
                .scaleEffect(1 - 0.3 * s.gallery)
                .offset(y: -18 * s.gallery)
            Text("Customize")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: 92, height: 24)
                .background(.white.opacity(0.92), in: Capsule())
                .position(x: 100, y: 383)
                .opacity(s.gallery)
            chooser(s)
            if s.flight != nil || s.sheet > 0 {
                LockGallery(cards: cards, rise: s.sheet, page: s.page, rowLit: s.rowLit, rectangularGone: s.flight != nil || s.placed)
            }
            if let flight = s.flight {
                MiniWidget(face: .tracker(cards[.rectangular]), size: .rectangular, width: Tween.mix(90, Self.slotWidth, flight))
                    .position(Tween.mix(CGPoint(x: 135, y: 282), Self.slot, flight))
            }
            popover(s)
            Fingertip(touch: s.touch)
        }
        .frame(width: 200, height: 430)
    }

    /// The Lock Screen itself, plain or being edited.
    private func face(_ s: LockState) -> some View {
        ZStack {
            LinearGradient(colors: [Palette.tangerine, Palette.marigold, Palette.sand], startPoint: .top, endPoint: .bottom)
            Circle().fill(Palette.paper.opacity(0.2)).frame(width: 240).position(x: 170, y: 360)
            PhoneStatusBar().opacity(1 - s.edit)
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .position(x: 100, y: 62)
            Text("9:41")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .position(x: 100, y: 104)
            // Editing: the clock gets a frame and the empty box shows a plus.
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.7), lineWidth: 1)
                .frame(width: 160, height: 66)
                .position(x: 100, y: 104)
                .opacity(s.edit)
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: s.placed ? [] : [3, 3]))
                .background(.white.opacity(0.18 * s.boxLit), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(s.placed || s.flight != nil ? 0 : 1)
                }
                .frame(width: Self.box.width, height: Self.box.height)
                .position(x: Self.box.midX, y: Self.box.midY)
                .opacity(s.edit)
            if s.placed {
                PickedWidget(content: cards[.rectangular], size: .rectangular, width: Self.slotWidth, picked: s.picked)
                    .position(Self.slot)
            }
            HStack {
                Text("Cancel")
                Spacer()
                Text("Done").fontWeight(.bold)
            }
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(width: 200)
            .position(x: 100, y: 34)
            .opacity(s.edit)
            ForEach(Array(["flashlight.off.fill", "camera.fill"].enumerated()), id: \.offset) { index, symbol in
                Image(systemName: symbol)
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(.black.opacity(0.18), in: Circle())
                    .position(x: index == 0 ? 36 : 164, y: 392)
            }
            .opacity(1 - s.edit)
            Capsule().fill(.white.opacity(0.9)).frame(width: 70, height: 3.5).position(x: 100, y: 420)
        }
        .frame(width: 200, height: 430)
    }

    /// Customize asks which screen: Lock Screen or Home Screen.
    private func chooser(_ s: LockState) -> some View {
        ZStack {
            Color.black.opacity(0.55)
            HStack(spacing: 14) {
                VStack(spacing: 8) {
                    ZStack {
                        LinearGradient(colors: [Palette.tangerine, Palette.marigold], startPoint: .top, endPoint: .bottom)
                        Text("9:41").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(.white).offset(y: -48)
                    }
                    .frame(width: 76, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .scaleEffect(1 + 0.05 * s.chooserLit)
                    Text("Lock Screen")
                }
                VStack(spacing: 8) {
                    ZStack {
                        LinearGradient(colors: [Palette.marigold, Palette.tangerine], startPoint: .top, endPoint: .bottom)
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(10), spacing: 6), count: 4), spacing: 8) {
                            ForEach(0..<16, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.6)).frame(width: 10, height: 10)
                            }
                        }
                        .offset(y: -30)
                    }
                    .frame(width: 76, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Text("Home Screen")
                }
            }
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.white)
            .position(x: 100, y: 228)
            .scaleEffect(0.9 + 0.1 * s.chooser)
        }
        .opacity(s.chooser)
    }

    /// Tapping the new widget asks for its tracker.
    private func popover(_ s: LockState) -> some View {
        ZStack {
            HStack {
                Text("Tracker").foregroundStyle(Palette.ink)
                Spacer()
                Text(s.picked > 0.5 ? cards.title : "Choose").lineLimit(1).foregroundStyle(Color.blue)
            }
            .opacity(1 - s.list)
            HStack {
                Text(cards.title).foregroundStyle(Palette.ink).lineLimit(1)
                Spacer()
                Image(systemName: "checkmark").foregroundStyle(Color.blue).opacity(s.check)
            }
            .opacity(s.list)
        }
        .font(.system(size: 9.5, weight: .semibold))
        .padding(.horizontal, 14)
        .frame(width: 164, height: 44)
        .background(.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        .scaleEffect(0.85 + 0.15 * s.popover, anchor: .top)
        .opacity(s.popover)
        .position(x: 100, y: 230)
    }
}

/// Every moving part of the Lock Screen scene at one moment.
private struct LockState {
    /// The Lock Screen shrunk into the wallpaper gallery.
    var gallery = 0.0
    var chooser = 0.0
    var chooserLit = 0.0
    var edit = 1.0
    var boxLit = 0.0
    var sheet = 0.0
    var page = 0.0
    var rowLit = 0.0
    var flight: Double?
    var placed = false
    var picked = 0.0
    var popover = 0.0
    var list = 0.0
    var check = 0.0
    var touch = Touch(at: .zero, opacity: 0)

    init(_ beat: GuideBeat) {
        let t = beat.t
        switch beat.step {
        case 0:
            edit = Tween.ramp(t, 3.35, 3.75)
            gallery = Tween.ramp(t, 1.4, 1.8) * (1 - edit)
            chooser = Tween.window(t, 2.45, 3.35, fade: 0.3)
            chooserLit = Tween.window(t, 3.2, 3.35, fade: 0.08)
            touch = TouchScript(
                moves: [(0, CGPoint(x: 100, y: 280)), (1.8, CGPoint(x: 100, y: 280)), (2.1, CGPoint(x: 100, y: 383)),
                        (2.6, CGPoint(x: 100, y: 383)), (3.0, CGPoint(x: 55, y: 215))],
                taps: [2.3, 3.2], longPresses: [0.5...1.4], enter: 0.2, leave: 3.45
            ).touch(at: t)
        case 1:
            boxLit = Tween.window(t, 1.1, 1.4, fade: 0.06)
            sheet = Tween.ramp(t, 1.3, 1.7)
            touch = TouchScript(moves: [(0, CGPoint(x: 100, y: 300)), (0.9, CGPoint(x: 100, y: 168))], taps: [1.1], enter: 0.2, leave: 1.5).touch(at: t)
        case 2:
            sheet = 1 - Tween.ramp(t, 3.1, 3.4)
            page = Tween.ramp(t, 1.1, 1.4)
            rowLit = Tween.window(t, 0.9, 1.3, fade: 0.08)
            if t >= 2.15, t < 2.7 { flight = Tween.land(t, 2.15, 2.7) }
            placed = t >= 2.7
            touch = TouchScript(
                moves: [(0, CGPoint(x: 150, y: 400)), (0.7, CGPoint(x: 100, y: 306)), (1.6, CGPoint(x: 100, y: 306)),
                        (1.95, CGPoint(x: 135, y: 282)), (2.6, CGPoint(x: 135, y: 282)), (2.85, CGPoint(x: 178, y: 208))],
                taps: [0.9, 2.1, 3.0], enter: 0.2, leave: 3.3
            ).touch(at: t)
        default:
            edit = 1 - Tween.ramp(t, 3.5, 3.9)
            placed = true
            popover = Tween.window(t, 0.8, 2.5, fade: 0.2)
            list = Tween.window(t, 1.6, 2.3, fade: 0.1)
            check = Tween.ramp(t, 2.2, 2.25)
            picked = Tween.ramp(t, 2.3, 2.55)
            touch = TouchScript(
                moves: [(0, CGPoint(x: 120, y: 300)), (0.55, CGPoint(x: 66, y: 168)), (0.9, CGPoint(x: 66, y: 168)),
                        (1.3, CGPoint(x: 150, y: 230)), (1.75, CGPoint(x: 150, y: 230)), (2.0, CGPoint(x: 100, y: 230)),
                        (2.6, CGPoint(x: 100, y: 230)), (3.1, CGPoint(x: 176, y: 34))],
                taps: [0.7, 1.5, 2.2, 3.3], enter: 0.2, leave: 3.7
            ).touch(at: t)
        }
    }
}

/// The dark Add Widgets sheet: apps, then Purrgets' Lock Screen sizes.
private struct LockGallery: View {
    var cards: GuideCards
    var rise: Double
    var page: Double
    var rowLit: Double
    var rectangularGone: Bool

    private static let apps = ["Batteries", "Calendar", "Purrgets", "Weather"]

    var body: some View {
        ZStack(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20, style: .continuous)
                .fill(Color(white: 0.16))
            Capsule().fill(.white.opacity(0.3)).frame(width: 30, height: 4).padding(.top, 6)
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .bold))
                .frame(width: 18, height: 18)
                .background(.white.opacity(0.15), in: Circle())
                .position(x: 178, y: 18)
            appList.offset(x: -200 * page)
            purrgetsPage.offset(x: 200 * (1 - page))
        }
        .foregroundStyle(.white)
        .frame(width: 200, height: 240)
        .clipped()
        .position(x: 100, y: 190 + 240 * (1 - rise) + 120)
    }

    private var appList: some View {
        ZStack {
            Text("Add Widgets").font(.system(size: 11, weight: .bold)).position(x: 100, y: 22)
            ForEach(Array(Self.apps.enumerated()), id: \.offset) { index, name in
                HStack(spacing: 8) {
                    if name == "Purrgets" {
                        MiniAppIcon(side: 18)
                    } else {
                        StandInIcon(color: .white.opacity(0.25), side: 18, symbol: nil)
                    }
                    Text(name).font(.system(size: 10, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold)).opacity(0.4)
                }
                .padding(.horizontal, 10)
                .frame(width: 180, height: 26)
                .background(.white.opacity(name == "Purrgets" ? 0.15 * rowLit : 0), in: RoundedRectangle(cornerRadius: 7))
                .position(x: 100, y: 56 + CGFloat(index) * 25)
            }
        }
        .frame(width: 200, height: 240)
    }

    private var purrgetsPage: some View {
        ZStack {
            HStack(spacing: 5) {
                MiniAppIcon(side: 14)
                Text("Purrgets").font(.system(size: 11, weight: .bold))
            }
            .position(x: 100, y: 22)
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.08)).frame(width: 52, height: 52).position(x: 50, y: 92)
            MiniWidget(face: .tracker(cards[.circular]), size: .circular, width: 42).position(x: 50, y: 92)
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.08)).frame(width: 104, height: 52).position(x: 135, y: 92)
            MiniWidget(face: .tracker(cards[.rectangular]), size: .rectangular, width: 90)
                .opacity(rectangularGone ? 0 : 1)
                .position(x: 135, y: 92)
            Text("Tap a widget to add it").font(.system(size: 8, weight: .medium)).opacity(0.6).position(x: 100, y: 140)
        }
        .frame(width: 200, height: 240)
    }
}
