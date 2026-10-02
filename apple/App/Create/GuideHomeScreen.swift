import SwiftUI

/// iPhone Home Screen: hold to jiggle, Edit → Add Widget, find Purrgets, swipe to a size, add it,
/// then hold it → Edit Widget → pick the tracker. Drawn on a 200 × 430 screen.
struct HomeScreenScene: View {
    var beat: GuideBeat
    var cards: GuideCards

    private static let columns: [CGFloat] = [41.5, 80.5, 119.5, 158.5]
    private static let rows: [CGFloat] = [70, 118, 166, 214]
    /// How far the icons move down to make room for the widget.
    private static let room: CGFloat = 84
    private static let slot = CGPoint(x: 100, y: 82)
    private static let slotWidth: CGFloat = 150
    private static let iconColors: [Color] = [
        Palette.ink, Palette.paper, Color(hex: 0x4F7CAC), Palette.sand,
        Color(hex: 0x6FA26B), .white.opacity(0.85), Palette.marigold, Color(hex: 0xD55A4A),
        Palette.sand, Palette.ink.opacity(0.75), Palette.paper, Color(hex: 0x4F7CAC),
        Palette.marigold, Color(hex: 0x6FA26B), Palette.ink, .white.opacity(0.85),
    ]
    private static let symbols: [String?] = [
        "camera.fill", nil, "map.fill", nil, "message.fill", nil, nil, "music.note",
        nil, "clock.fill", nil, nil, "sun.max.fill", "leaf.fill", nil, nil,
    ]

    var body: some View {
        let s = HomeState(beat)
        ZStack {
            LinearGradient(colors: [Palette.marigold, Palette.tangerine], startPoint: .top, endPoint: .bottom)
            Circle().fill(Palette.paper.opacity(0.18)).frame(width: 260).position(x: 40, y: 330)
            PhoneStatusBar().opacity(1 - s.jiggle)
            icons(s)
            if s.placed {
                PickedWidget(content: cards[.medium], size: .medium, width: Self.slotWidth, picked: s.picked)
                    .scaleEffect(1 + 0.06 * s.lift)
                    .shadow(color: Palette.ink.opacity(0.3 * s.lift), radius: 10, y: 6)
                    .rotationEffect(wobble(seed: 0, s))
                    .opacity(1 - s.config)
                    .position(Self.slot)
                    .zIndex(1)
            }
            dock(s)
            editButtons(s)
            editMenu(s)
            Color.black.opacity(0.4 * s.dim)
            if s.lift > 0 {
                // The lifted widget stays bright above the dimmed screen.
                PickedWidget(content: cards[.medium], size: .medium, width: Self.slotWidth, picked: s.picked)
                    .scaleEffect(1.06)
                    .opacity(s.lift)
                    .position(Self.slot)
            }
            contextMenu(s)
            configCard(s)
            PhoneGallery(cards: cards, rise: s.sheet, page: s.page, rowLit: s.rowLit, swipe: s.swipe, mediumGone: s.flight != nil)
            if let flight = s.flight {
                PickedWidget(content: cards[.medium], size: .medium, width: Tween.mix(170, Self.slotWidth, flight.move), picked: 1 - flight.blank)
                    .shadow(color: Palette.ink.opacity(0.25), radius: 10, y: 6)
                    .position(Tween.mix(CGPoint(x: 100, y: 210), Self.slot, flight.move))
            }
            Fingertip(touch: s.touch)
        }
        .frame(width: 200, height: 430)
    }

    private func wobble(seed: Int, _ s: HomeState) -> Angle {
        .degrees(sin(beat.clock * 24 + Double(seed) * 1.7) * 2 * s.jiggle)
    }

    private func icons(_ s: HomeState) -> some View {
        ForEach(0..<16, id: \.self) { index in
            VStack(spacing: 4) {
                StandInIcon(color: Self.iconColors[index], side: 30, symbol: Self.symbols[index])
                Capsule().fill(.white.opacity(0.6)).frame(width: 20, height: 3)
            }
            .rotationEffect(wobble(seed: index + 1, s))
            .position(x: Self.columns[index % 4], y: Self.rows[index / 4] + 4 + Self.room * CGFloat(s.shift))
        }
    }

    private func dock(_ s: HomeState) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.28)).frame(width: 186, height: 48)
            ForEach(0..<4, id: \.self) { index in
                Group {
                    if index == 3 {
                        MiniAppIcon(side: 30)
                    } else {
                        StandInIcon(color: [Color(hex: 0x6FA26B), Color(hex: 0x4F7CAC), Palette.paper][index], side: 30,
                                    symbol: ["phone.fill", "safari.fill", nil][index])
                    }
                }
                .rotationEffect(wobble(seed: 20 + index, s))
                .position(x: Self.columns[index] - 7, y: 24)
            }
        }
        .frame(width: 186, height: 48)
        .position(x: 100, y: 398)
    }

    private func editButtons(_ s: HomeState) -> some View {
        ZStack {
            pill("Edit").position(x: 26, y: 36)
            pill("Done").position(x: 174, y: 36)
        }
        .opacity(s.jiggle)
    }

    private func pill(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 18)
            .background(.white.opacity(0.3), in: Capsule())
    }

    private func editMenu(_ s: HomeState) -> some View {
        VStack(spacing: 0) {
            menuRow("Add Widget", symbol: "plus.square.on.square", lit: s.menuLit)
            Divider()
            menuRow("Customize", symbol: "paintbrush", lit: 0)
        }
        .frame(width: 112)
        .background(.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .shadow(color: Palette.ink.opacity(0.2), radius: 10, y: 4)
        .scaleEffect(0.6 + 0.4 * s.menu, anchor: .topLeading)
        .opacity(s.menu)
        .position(x: 68, y: 72)
    }

    private func contextMenu(_ s: HomeState) -> some View {
        VStack(spacing: 0) {
            menuRow("Edit Widget", symbol: "info.circle", lit: s.contextLit)
            Divider()
            menuRow("Edit Home Screen", symbol: "apps.iphone", lit: 0)
            Divider()
            menuRow("Remove Widget", symbol: "minus.circle", lit: 0, tint: .red)
        }
        .frame(width: 130)
        .background(.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .scaleEffect(0.6 + 0.4 * s.contextMenu, anchor: .top)
        .opacity(s.contextMenu)
        .position(x: 92, y: 157)
    }

    private func menuRow(_ title: String, symbol: String, lit: Double, tint: Color = Palette.ink) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 4)
            Image(systemName: symbol)
        }
        .font(.system(size: 8.5, weight: .medium))
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .frame(height: 22)
        .background(Palette.ink.opacity(0.1 * lit))
    }

    /// Edit Widget: the card big in the middle, the Tracker setting under it.
    private func configCard(_ s: HomeState) -> some View {
        ZStack {
            PickedWidget(content: cards[.medium], size: .medium, width: 172, picked: s.picked)
                .position(x: 100, y: 150)
            ZStack {
                HStack {
                    Text("Tracker").foregroundStyle(Palette.ink)
                    Spacer()
                    Text(s.picked > 0.5 ? cards.title : "Choose")
                        .lineLimit(1)
                        .foregroundStyle(Color.blue)
                }
                .opacity(1 - s.list)
                HStack {
                    Text(cards.title).foregroundStyle(Palette.ink).lineLimit(1)
                    Spacer()
                    Image(systemName: "checkmark").foregroundStyle(Color.blue).opacity(s.check)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 6)
                .background(Palette.ink.opacity(0.08 * s.check), in: RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, -6)
                .opacity(s.list)
            }
            .font(.system(size: 9.5, weight: .semibold))
            .padding(.horizontal, 14)
            .frame(width: 172, height: 40)
            .background(.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .position(x: 100, y: 232)
        }
        .scaleEffect(0.92 + 0.08 * s.config)
        .opacity(s.config)
    }
}

/// Every moving part of the Home Screen scene at one moment.
private struct HomeState {
    var jiggle = 1.0
    var shift = 0.0
    var placed = false
    var picked = 0.0
    var menu = 0.0
    var menuLit = 0.0
    var sheet = 0.0
    var page = 0.0
    var rowLit = 0.0
    var swipe = 0.0
    /// The new widget on its way from the gallery to the Home Screen.
    var flight: (move: Double, blank: Double)?
    var lift = 0.0
    var contextMenu = 0.0
    var contextLit = 0.0
    var dim = 0.0
    var config = 0.0
    var list = 0.0
    var check = 0.0
    var touch = Touch(at: .zero, opacity: 0)

    init(_ beat: GuideBeat) {
        let t = beat.t
        switch beat.step {
        case 0:
            jiggle = Tween.ramp(t, 1.75, 1.95)
            touch = TouchScript(moves: [(0, CGPoint(x: 120, y: 300))], longPresses: [0.8...1.8], enter: 0.3, leave: 2.2).touch(at: t)
        case 1:
            menu = Tween.window(t, 1.0, 2.25)
            menuLit = Tween.window(t, 1.95, 2.25, fade: 0.05)
            sheet = Tween.ramp(t, 2.4, 2.9)
            touch = TouchScript(
                moves: [(0, CGPoint(x: 90, y: 220)), (0.75, CGPoint(x: 26, y: 36)), (1.25, CGPoint(x: 26, y: 36)), (1.75, CGPoint(x: 50, y: 61))],
                taps: [0.9, 1.95], enter: 0.1, leave: 2.3
            ).touch(at: t)
        case 2:
            sheet = 1
            rowLit = Tween.window(t, 1.35, 2.0, fade: 0.08)
            page = Tween.ramp(t, 1.9, 2.3)
            touch = TouchScript(moves: [(0, CGPoint(x: 150, y: 390)), (1.1, CGPoint(x: 100, y: 299))], taps: [1.35], enter: 0.2, leave: 1.7).touch(at: t)
        case 3:
            sheet = 1 - Tween.ramp(t, 2.55, 2.95)
            page = 1
            swipe = Tween.ramp(t, 0.85, 1.4)
            shift = Tween.ramp(t, 2.6, 3.1)
            placed = t >= 3.15
            if t >= 2.45, t < 3.15 { flight = (Tween.land(t, 2.5, 3.15), Tween.ramp(t, 2.85, 3.15)) }
            touch = TouchScript(
                moves: [(0, CGPoint(x: 160, y: 215)), (0.85, CGPoint(x: 160, y: 215)), (1.4, CGPoint(x: 50, y: 215)), (2.1, CGPoint(x: 100, y: 341))],
                taps: [2.3], drags: [0.85...1.4], enter: 0.3, leave: 2.6
            ).touch(at: t)
        default:
            jiggle = 1 - Tween.ramp(t, 0.6, 0.8)
            shift = 1
            placed = true
            lift = Tween.window(t, 1.8, 2.5)
            contextMenu = Tween.window(t, 1.85, 2.45)
            contextLit = Tween.window(t, 2.4, 2.5, fade: 0.05)
            dim = Tween.window(t, 1.8, 4.45, fade: 0.2)
            config = Tween.window(t, 2.6, 4.35, fade: 0.2)
            list = Tween.window(t, 3.3, 3.85, fade: 0.1)
            check = Tween.ramp(t, 3.75, 3.8)
            picked = Tween.ramp(t, 3.85, 4.15)
            touch = TouchScript(
                moves: [
                    (0, CGPoint(x: 130, y: 300)), (0.4, CGPoint(x: 174, y: 36)), (0.8, CGPoint(x: 174, y: 36)),
                    (1.05, CGPoint(x: 100, y: 84)), (1.85, CGPoint(x: 100, y: 84)), (2.2, CGPoint(x: 66, y: 135)),
                    (2.8, CGPoint(x: 66, y: 135)), (3.05, CGPoint(x: 156, y: 232)), (3.35, CGPoint(x: 156, y: 232)),
                    (3.55, CGPoint(x: 100, y: 232)), (4.0, CGPoint(x: 100, y: 232)), (4.2, CGPoint(x: 100, y: 345)),
                ],
                taps: [0.5, 2.4, 3.2, 3.75, 4.3], longPresses: [1.1...1.8], enter: 0.1, leave: 4.55
            ).touch(at: t)
        }
    }
}

/// The widget gallery sheet: the app list, then Purrgets' own page with its sizes.
private struct PhoneGallery: View {
    var cards: GuideCards
    var rise: Double
    var page: Double
    var rowLit: Double
    var swipe: Double
    var mediumGone: Bool

    private static let apps: [(String, Color, String?)] = [
        ("Batteries", Color(hex: 0x6FA26B), "battery.75percent"), ("Calendar", .white, nil),
        ("Clock", Palette.ink, "clock.fill"), ("Purrgets", Palette.tangerine, nil), ("Weather", Color(hex: 0x4F7CAC), "cloud.sun.fill"),
    ]

    var body: some View {
        ZStack(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous)
                .fill(Color(white: 0.95))
                .shadow(color: .black.opacity(0.2), radius: 10, y: -2)
            Capsule().fill(.black.opacity(0.2)).frame(width: 30, height: 4).padding(.top, 6)
            appList.offset(x: -200 * page)
            purrgetsPage.offset(x: 200 * (1 - page))
        }
        .frame(width: 200, height: 390)
        .clipped()
        .position(x: 100, y: 40 + 390 * (1 - rise) + 195)
        .opacity(rise > 0 ? 1 : 0)
    }

    private var appList: some View {
        ZStack {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                Text("Search Widgets")
                Spacer()
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .frame(width: 172, height: 22)
            .background(.black.opacity(0.07), in: Capsule())
            .position(x: 100, y: 30)
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: 0x4F7CAC).opacity(0.75))
                .frame(width: 80, height: 80).position(x: 56, y: 96)
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.sand)
                .frame(width: 80, height: 80).position(x: 144, y: 96)
            ForEach(Array(Self.apps.enumerated()), id: \.offset) { index, app in
                HStack(spacing: 8) {
                    if app.0 == "Purrgets" {
                        MiniAppIcon(side: 20)
                    } else {
                        StandInIcon(color: app.1, side: 20, symbol: app.2)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(.black.opacity(0.08)))
                    }
                    Text(app.0).font(.system(size: 10, weight: .semibold)).foregroundStyle(Palette.ink)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold)).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 10)
                .frame(width: 180, height: 30)
                .background(.black.opacity(app.0 == "Purrgets" ? 0.1 * rowLit : 0), in: RoundedRectangle(cornerRadius: 8))
                .position(x: 100, y: 160 + CGFloat(index) * 33)
            }
        }
        .frame(width: 200, height: 390)
    }

    private var purrgetsPage: some View {
        ZStack {
            HStack(spacing: 5) {
                MiniAppIcon(side: 16)
                Text("Purrgets").font(.system(size: 10, weight: .semibold))
            }
            .position(x: 100, y: 28)
            Text("Tracker").font(.system(size: 15, weight: .bold)).position(x: 100, y: 62)
            Text("A countdown, time since or progress tracker.")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
                .position(x: 100, y: 80)
            MiniWidget(face: .tracker(cards[.small]), size: .small, width: 112)
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                .position(x: 100 - 200 * swipe, y: 170)
            MiniWidget(face: .tracker(cards[.medium]), size: .medium, width: 170)
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                .opacity(mediumGone ? 0 : 1)
                .position(x: 300 - 200 * swipe, y: 170)
            HStack(spacing: 5) {
                Circle().fill(.black.opacity(0.25 + 0.5 * (1 - swipe)))
                Circle().fill(.black.opacity(0.25 + 0.5 * swipe))
            }
            .frame(width: 17, height: 6)
            .position(x: 100, y: 250)
            Label("Add Widget", systemImage: "plus")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 130, height: 30)
                .background(Color.blue, in: Capsule())
                .position(x: 100, y: 301)
        }
        .foregroundStyle(Palette.ink)
        .frame(width: 200, height: 390)
    }
}
