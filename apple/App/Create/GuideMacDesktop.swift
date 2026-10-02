import SwiftUI

/// Mac desktop: right-click → Edit Widgets, find Purrgets in the gallery, drag a size out, click Done,
/// then right-click the widget → Edit "Tracker" and pick the tracker. Drawn on a 400 × 250 screen.
struct MacDesktopScene: View {
    var beat: GuideBeat
    var cards: GuideCards

    private static let slot = CGPoint(x: 70, y: 62)
    private static let slotWidth: CGFloat = 52
    private static let galleryTop: CGFloat = 128
    private static let apps = ["Calendar", "Clock", "Notes", "Purrgets", "Weather"]

    var body: some View {
        let s = MacState(beat)
        ZStack {
            LinearGradient(colors: [Palette.marigold, Palette.tangerine], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(Palette.paper.opacity(0.2)).frame(width: 300).position(x: 330, y: 230)
            desktopIcons
            dock
            menuBar
            if s.placed {
                PickedWidget(content: cards[.small], size: .small, width: Self.slotWidth, picked: s.picked)
                    .scaleEffect(s.landing)
                    .shadow(color: Palette.ink.opacity(0.15), radius: 4, y: 2)
                    .position(Self.slot)
            }
            gallery(s)
            if let drag = s.dragAt {
                MiniWidget(face: .tracker(cards[.small]), size: .small, width: Self.slotWidth)
                    .scaleEffect(1.08)
                    .shadow(color: Palette.ink.opacity(0.3), radius: 8, y: 5)
                    .position(drag)
            }
            MacMenu(items: ["New Folder", "Get Info", nil, "Change Wallpaper…", "Edit Widgets…"], lit: s.desktopLit ? 4 : nil, width: 112)
                .reveal(s.desktopMenu, top: 110, left: 150)
            MacMenu(items: ["Edit “Tracker”…", "✓ Small", "Medium", nil, "Remove Widget"], lit: s.widgetLit ? 0 : nil, width: 100)
                .reveal(s.widgetMenu, top: 66, left: 78)
            settings(s)
            MacMenu(items: [cards.title], lit: s.check ? 0 : nil, width: 76)
                .reveal(s.dropdown, top: 77, left: 152)
            Cursor(touch: s.touch)
        }
        .frame(width: 400, height: 250)
        .clipped()
    }

    private var menuBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "apple.logo")
            Text("Finder").fontWeight(.bold)
            ForEach(["File", "Edit", "View", "Go", "Window", "Help"], id: \.self) { Text($0) }
            Spacer()
            Image(systemName: "wifi")
            Text(Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) + "  9:41")
        }
        .font(.system(size: 7, weight: .medium))
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 10)
        .frame(width: 400, height: 13)
        .background(.white.opacity(0.35))
        .position(x: 200, y: 6.5)
    }

    private var desktopIcons: some View {
        ForEach(0..<2, id: \.self) { index in
            VStack(spacing: 2) {
                Image(systemName: "folder.fill").font(.system(size: 20)).foregroundStyle(Color(hex: 0x7FB2E5))
                Capsule().fill(.white.opacity(0.8)).frame(width: 22, height: 3)
            }
            .position(x: 372, y: 36 + CGFloat(index) * 40)
        }
    }

    private var dock: some View {
        HStack(spacing: 4) {
            ForEach(0..<8, id: \.self) { index in
                if index == 6 {
                    MiniAppIcon(side: 16)
                } else {
                    StandInIcon(color: [Color(hex: 0x4F7CAC), .white, Color(hex: 0x6FA26B), Palette.ink, Palette.sand, Color(hex: 0xD55A4A), .clear, Palette.paper][index], side: 16, symbol: nil)
                }
            }
        }
        .padding(4)
        .background(.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .position(x: 200, y: 236)
    }

    /// The widget gallery along the bottom of the screen.
    private func gallery(_ s: MacState) -> some View {
        ZStack(alignment: .topLeading) {
            UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10, style: .continuous)
                .fill(Color(white: 0.95))
                .shadow(color: .black.opacity(0.2), radius: 10, y: -2)
            Rectangle().fill(.black.opacity(0.05)).frame(width: 96)
            HStack(spacing: 3) {
                Image(systemName: "magnifyingglass")
                Text("Search")
            }
            .font(.system(size: 7))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .frame(width: 80, height: 13, alignment: .leading)
            .background(.black.opacity(0.07), in: RoundedRectangle(cornerRadius: 4))
            .offset(x: 8, y: 8)
            ForEach(Array(Self.apps.enumerated()), id: \.offset) { index, name in
                HStack(spacing: 5) {
                    if name == "Purrgets" { MiniAppIcon(side: 10) } else { StandInIcon(color: Palette.sand, side: 10, symbol: nil) }
                    Text(name).font(.system(size: 7.5, weight: .medium))
                    Spacer()
                }
                .padding(.horizontal, 5)
                .frame(width: 84, height: 13)
                .background(.black.opacity((s.purrgetsPicked ? name == "Purrgets" : index == 0) ? 0.1 : 0), in: RoundedRectangle(cornerRadius: 4))
                .offset(x: 6, y: 28 + CGFloat(index) * 15)
            }
            Text(s.purrgetsPicked ? "Purrgets" : "Calendar")
                .font(.system(size: 9, weight: .bold))
                .offset(x: 110, y: 10)
            Group {
                if s.purrgetsPicked {
                    MiniWidget(face: .tracker(cards[.small]), size: .small, width: Self.slotWidth)
                        .position(x: 170, y: 64)
                    MiniWidget(face: .tracker(cards[.medium]), size: .medium, width: 110)
                        .position(x: 268, y: 64)
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white).frame(width: 52, height: 52).position(x: 170, y: 64)
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white).frame(width: 110, height: 52).position(x: 268, y: 64)
                }
            }
            .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
            Text("Done")
                .font(.system(size: 7.5, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 13)
                .background(Color.blue, in: RoundedRectangle(cornerRadius: 4))
                .position(x: 372, y: 110)
        }
        .foregroundStyle(Palette.ink)
        .frame(width: 400, height: 122, alignment: .topLeading)
        .position(x: 200, y: Self.galleryTop + 61 + 130 * (1 - s.gallery))
        .opacity(s.gallery > 0 ? 1 : 0)
    }

    /// Edit "Tracker": the widget's settings next to it.
    private func settings(_ s: MacState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose a tracker").font(.system(size: 7, weight: .medium)).foregroundStyle(.secondary)
            HStack {
                Text("Tracker").font(.system(size: 7.5, weight: .semibold))
                Spacer()
                HStack(spacing: 3) {
                    Text(s.picked > 0.5 ? cards.title : "Choose").lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 5, weight: .bold))
                }
                .font(.system(size: 7))
                .padding(.horizontal, 5)
                .frame(width: 70, height: 13, alignment: .trailing)
                .background(.white, in: RoundedRectangle(cornerRadius: 4))
                .shadow(color: .black.opacity(0.15), radius: 0.5, y: 0.5)
            }
            HStack {
                Spacer()
                Text("Done")
                    .font(.system(size: 7.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 13)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 4))
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(8)
        .frame(width: 128)
        .background(Color(white: 0.96), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
        .scaleEffect(0.85 + 0.15 * s.settings, anchor: .leading)
        .opacity(s.settings)
        .position(x: 166, y: 72)
    }
}

/// Every moving part of the Mac scene at one moment.
private struct MacState {
    var desktopMenu = 0.0
    var desktopLit = false
    var gallery = 0.0
    var purrgetsPicked = true
    var dragAt: CGPoint?
    var placed = false
    var landing = 1.0
    var widgetMenu = 0.0
    var widgetLit = false
    var settings = 0.0
    var dropdown = 0.0
    var check = false
    var picked = 0.0
    var touch: Touch

    init(_ beat: GuideBeat) {
        let t = beat.t
        switch beat.step {
        case 0:
            purrgetsPicked = false
            desktopMenu = Tween.window(t, 1.0, 2.15, fade: 0.08)
            desktopLit = t >= 1.8 && t < 2.15
            gallery = Tween.ramp(t, 2.35, 2.8)
            touch = TouchScript(
                moves: [(0, CGPoint(x: 300, y: 200)), (0.8, CGPoint(x: 150, y: 110)), (1.3, CGPoint(x: 150, y: 110)), (1.75, CGPoint(x: 185, y: 160))],
                taps: [0.95, 2.0], enter: -1
            ).touch(at: t)
        case 1:
            gallery = 1
            purrgetsPicked = t >= 1.2
            touch = TouchScript(moves: [(0, CGPoint(x: 185, y: 160)), (1.0, CGPoint(x: 45, y: 205))], taps: [1.2], enter: -1).touch(at: t)
        case 2:
            gallery = 1 - Tween.ramp(t, 3.0, 3.4)
            let script = TouchScript(
                moves: [(0, CGPoint(x: 45, y: 205)), (0.6, CGPoint(x: 170, y: 192)), (0.75, CGPoint(x: 170, y: 192)),
                        (1.85, CGPoint(x: 70, y: 62)), (2.2, CGPoint(x: 70, y: 62)), (2.7, CGPoint(x: 372, y: 238))],
                taps: [2.9], drags: [0.75...1.9], enter: -1
            )
            touch = script.touch(at: t)
            if t >= 0.75, t < 1.9 { dragAt = touch.at }
            placed = t >= 1.9
            landing = 1.08 - 0.08 * Tween.land(t, 1.9, 2.2)
        default:
            placed = true
            widgetMenu = Tween.window(t, 0.9, 1.55, fade: 0.08)
            widgetLit = t >= 1.3 && t < 1.55
            settings = Tween.window(t, 1.7, 3.7, fade: 0.2)
            dropdown = Tween.window(t, 2.35, 2.95, fade: 0.06)
            check = t >= 2.75
            picked = Tween.ramp(t, 3.0, 3.25)
            touch = TouchScript(
                moves: [(0, CGPoint(x: 372, y: 238)), (0.7, CGPoint(x: 78, y: 66)), (1.0, CGPoint(x: 78, y: 66)),
                        (1.3, CGPoint(x: 112, y: 76)), (1.8, CGPoint(x: 112, y: 76)), (2.1, CGPoint(x: 190, y: 70)),
                        (2.5, CGPoint(x: 190, y: 70)), (2.7, CGPoint(x: 180, y: 87)), (3.15, CGPoint(x: 180, y: 87)),
                        (3.4, CGPoint(x: 206, y: 97))],
                taps: [0.85, 1.5, 2.3, 2.9, 3.6], enter: -1
            ).touch(at: t)
        }
    }
}

/// A Mac context menu. nil items are separators.
private struct MacMenu: View {
    var items: [String?]
    var lit: Int?
    var width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if let item {
                    Text(item)
                        .font(.system(size: 7.5, weight: .medium))
                        .foregroundStyle(lit == index ? .white : Palette.ink)
                        .padding(.horizontal, 6)
                        .frame(width: width - 8, height: 12.5, alignment: .leading)
                        .background(lit == index ? Color.blue : .clear, in: RoundedRectangle(cornerRadius: 3))
                } else {
                    Rectangle().fill(.black.opacity(0.1)).frame(width: width - 16, height: 0.5).padding(.horizontal, 4).frame(height: 6)
                }
            }
        }
        .padding(4)
        .frame(width: width, alignment: .leading)
        .background(Color(white: 0.96), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
    }
}

private extension View {
    /// Pops in with its top-left corner at the given point, as a menu does under the cursor.
    func reveal(_ amount: Double, top: CGFloat, left: CGFloat) -> some View {
        self
            .fixedSize()
            .scaleEffect(0.9 + 0.1 * amount, anchor: .topLeading)
            .opacity(amount)
            .frame(width: 400, height: 250, alignment: .topLeading)
            .offset(x: left, y: top)
            .allowsHitTesting(false)
    }
}
