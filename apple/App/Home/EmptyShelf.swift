import SharedLogic
import SwiftUI

/// First launch: the cat sits on a shelf of template cards and knocks them off, one at a time.
/// The one that lands is the suggestion: tap it to start, swipe it away (or ask) for the next.
struct EmptyShelf: View {
    var templates: [Template]
    var pick: (Template) -> Void

    @Environment(TrackerStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Every card on screen: on the shelf, landed, or flying away.
    @State private var items: [Item] = []
    /// The cards on the shelf, nearest the cat first.
    @State private var shelf: [Int] = []
    @State private var landed: Int?
    @State private var tipping: Int?
    /// Cards being thrown off screen, to the left (-1) or right (1).
    @State private var leaving: [Int: CGFloat] = [:]
    /// Each card's spin, so a falling card tumbles and a thrown one keeps turning.
    @State private var spin: [Int: Double] = [:]
    /// How far a thrown card has dropped. Animated apart from its sideways flight, so together they make an arc.
    @State private var drop: [Int: CGFloat] = [:]
    @State private var drag: CGFloat = 0
    @State private var nextTemplate = 0
    @State private var nextID = 0

    @State private var cat = CatPoseState()
    @State private var busy = false
    @State private var hops = 0
    /// The cat drops onto the shelf from above when the scene first appears.
    @State private var catDrop: CGFloat = -360
    @State private var thuds = 0
    /// When the person last did something; the cat only fidgets after a quiet spell.
    @State private var lastTouch = Date.now

    var body: some View {
        VStack(spacing: 6) {
            VStack(spacing: 8) {
                Text("Nothing to count yet")
                    .font(.rounded(22, .black))
                Text(landed == nil ? "Hang on, he's picking one for you." : "He picked this one. Tap it to start, or ask for another.")
                    .font(.rounded(15, .bold))
                    .foregroundStyle(Palette.ink.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                    .motion(Motion.gentle, value: landed == nil)
            }
            .padding(.top, 12)
            .arrive()

            GeometryReader { geo in
                scene(Layout(width: geo.size.width))
            }
            .frame(height: Layout.height)
            .frame(maxWidth: 420)
            .arrive(1)

            buttons
                .arrive(2)
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(Palette.ink)
        .sensoryFeedback(.impact(weight: .medium), trigger: thuds)
        .sensoryFeedback(.impact(weight: .light), trigger: hops)
        .task { await run() }
    }

    // MARK: - Scene

    private func scene(_ layout: Layout) -> some View {
        ZStack(alignment: .topLeading) {
            // Where the card lands, until one does.
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Palette.ink.opacity(0.12), style: StrokeStyle(lineWidth: 2, dash: [7, 7]))
                .frame(width: Layout.card, height: Layout.card)
                .position(layout.landing)
                .opacity(landed == nil ? 1 : 0)
                .motion(Motion.gentle, value: landed == nil)

            ShelfPlank()
                .frame(width: layout.width, height: 30)
                .position(x: layout.width / 2, y: Layout.shelfY + 15)

            ForEach(items) { item in
                card(item, layout)
            }

            ShelfCat(state: cat)
                .frame(width: Layout.catWidth, height: Layout.catHeight)
                .keyframeAnimator(initialValue: HopFrame(), trigger: hops) { view, frame in
                    view
                        .scaleEffect(x: frame.stretch, y: 1 / frame.stretch, anchor: .bottom)
                        .offset(y: frame.lift)
                } keyframes: { _ in
                    KeyframeTrack(\.lift) {
                        SpringKeyframe(0, duration: 0.06)
                        CubicKeyframe(-14, duration: 0.14)
                        SpringKeyframe(0, duration: 0.3, spring: .bouncy)
                    }
                    KeyframeTrack(\.stretch) {
                        CubicKeyframe(0.88, duration: 0.06)
                        CubicKeyframe(1.06, duration: 0.14)
                        SpringKeyframe(1, duration: 0.3, spring: .bouncy)
                    }
                }
                .position(x: Layout.catX + Layout.catWidth / 2, y: Layout.shelfY - Layout.catHeight / 2 + 1)
                .offset(y: catDrop)
                .contentShape(Rectangle())
                .onTapGesture {
                    touched()
                    hops += 1
                    Task { await knock(impatient: true) }
                }
                .accessibilityHidden(true)
        }
        .frame(width: layout.width, height: Layout.height, alignment: .topLeading)
    }

    @ViewBuilder private func card(_ item: Item, _ layout: Layout) -> some View {
        let place = place(of: item.id, layout)
        LiveCard(content: item.content, size: .small)
            .frame(width: Layout.card, height: Layout.card)
            .shadow(color: Palette.ink.opacity(place.isLanded ? 0.12 : 0), radius: 12, y: 6)
            .scaleEffect(place.scale)
            .rotationEffect(.degrees(place.rotation), anchor: place.isTipping ? .bottomTrailing : .center)
            .position(place.center)
            .offset(x: place.isLanded ? drag : 0)
            .offset(y: drop[item.id] ?? 0)
            .opacity(place.opacity)
            .zIndex(place.isLanded || leaving[item.id] != nil ? 1 : 0)
            .onTapGesture { tap(item) }
            .gesture(place.isLanded ? swipe(item) : nil)
            .accessibilityElement()
            .accessibilityLabel(item.title)
            .accessibilityHint(place.isLanded ? "Starts a tracker from this template" : "Asks the cat for this one")
            .accessibilityAddTraits(.isButton)
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            Button {
                touched()
                Task { await throwAway(-1, thenKnock: true) }
            } label: {
                Label("Another", systemImage: "arrow.uturn.left")
                    .font(.rounded(15, .heavy))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Palette.ink.opacity(0.07), in: Capsule())
            }
            .buttonStyle(SquishStyle())
            .disabled(landed == nil)

            Button {
                if let item = items.first(where: { $0.id == landed }) { pick(item.template) }
            } label: {
                Text("Start with this")
                    .font(.rounded(15, .heavy))
                    .foregroundStyle(Palette.paper)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Palette.ink, in: Capsule())
            }
            .buttonStyle(SquishStyle())
            .disabled(landed == nil)
        }
        .opacity(landed == nil ? 0.35 : 1)
        .motion(Motion.gentle, value: landed == nil)
        .foregroundStyle(Palette.ink)
    }

    private func swipe(_ item: Item) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                touched()
                drag = value.translation.width
            }
            .onEnded { value in
                let flung = value.predictedEndTranslation.width
                if abs(flung) > 110 {
                    Task { await throwAway(flung > 0 ? 1 : -1, thenKnock: true) }
                } else {
                    withAnimation(Motion.bouncy) { drag = 0 }
                }
            }
    }

    // MARK: - Where each card is

    private func place(of id: Int, _ layout: Layout) -> Place {
        let turn = spin[id] ?? 0
        if let side = leaving[id] {
            // Well past the screen edge, so it flies out rather than fading away.
            return Place(center: CGPoint(x: layout.landing.x + side * (layout.width + Layout.card), y: layout.landing.y), scale: 0.92, rotation: turn)
        }
        if id == landed {
            return Place(center: layout.landing, scale: 1, rotation: turn, isLanded: true)
        }
        guard let slot = shelf.firstIndex(of: id) else {
            return Place(center: layout.slot(layout.slots), scale: Layout.mini / Layout.card, rotation: 0, opacity: 0)
        }
        if id == tipping {
            var center = layout.slot(slot)
            center.x += 6
            return Place(center: center, scale: Layout.mini / Layout.card, rotation: 16, isTipping: true)
        }
        return Place(center: layout.slot(slot), scale: Layout.mini / Layout.card, rotation: turn, opacity: slot < layout.slots ? 1 : 0)
    }

    // MARK: - The cat's routine

    private func run() async {
        guard items.isEmpty, !templates.isEmpty else { return }
        for _ in 0..<5 { addToShelf() }
        // In he drops, lands with a squash, and has a look round.
        if reduceMotion {
            catDrop = 0
        } else {
            await nap(0.25)
            withAnimation(.easeIn(duration: 0.32)) { catDrop = 0 }
            await nap(0.32)
            hops += 1
            await nap(0.5)
        }
        await nap(0.5)
        await knock(impatient: false)
        // Fidgets while nobody's touching anything: blinks, glances, and a paw at the next card.
        while !Task.isCancelled {
            await nap(Double.random(in: 2.4...4.2))
            guard !busy, !reduceMotion else { continue }
            if Date.now.timeIntervalSince(lastTouch) > 5, Bool.random() {
                await tease()
            } else {
                await blink()
            }
        }
    }

    /// Looks at the next card, looks at you, and swipes it off the shelf. It lands as the suggestion.
    private func knock(impatient: Bool) async {
        guard !busy, let id = shelf.first else { return }
        busy = true
        defer { busy = false }

        if !reduceMotion {
            withAnimation(Motion.snappy) { cat.look = 1 }
            await nap(impatient ? 0.15 : 0.4)
            withAnimation(Motion.snappy) { cat.look = 0 }
            await nap(impatient ? 0.15 : 0.55)
            // Paw up, hold it over the card a beat, then down it comes.
            await show(.lift, for: 0.08)
            await show(.raise, for: impatient ? 0.25 : 0.5)
            show(.swat)
            await nap(0.06)
        }

        // The old suggestion makes room.
        if landed != nil { await throwAway(-1, thenKnock: false) }

        withAnimation(.easeIn(duration: 0.14)) { tipping = id }
        await nap(reduceMotion ? 0 : 0.14)
        withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(duration: 0.75, bounce: 0.32)) {
            tipping = nil
            spin[id] = reduceMotion ? 0 : 358
            landed = id
            shelf.removeFirst()
        }
        withAnimation(Motion.bouncy.delay(0.1)) { addToShelf() }
        thuds += 1

        await nap(0.3)
        await show(.lift, for: 0.08)
        show(.rest)
        // Pleased with himself.
        await nap(0.25)
        withAnimation(Motion.snappy) { cat.look = 1 }
        await nap(0.45)
        withAnimation(Motion.gentle) { cat.look = 0 }
    }

    /// Throws the landed card off screen, to [side]: it shoots out fast and tumbling, rises a little,
    /// then drops away like a real throw. The cat watches it go.
    private func throwAway(_ side: CGFloat, thenKnock: Bool) async {
        guard let id = landed else { return }
        let flight = reduceMotion ? 0.25 : 0.6
        withAnimation(reduceMotion ? .easeIn(duration: flight) : .timingCurve(0.15, 0.6, 0.4, 1, duration: flight)) {
            leaving[id] = side
            spin[id, default: 0] += reduceMotion ? 0 : side * 160
            landed = nil
            drag = 0
        }
        if !reduceMotion {
            // A pull back up first (control point below 0), then gravity takes over.
            withAnimation(.timingCurve(0.3, -0.5, 0.75, 0.6, duration: flight)) { drop[id] = 260 }
            if thenKnock { withAnimation(Motion.snappy) { cat.look = side } }
        }
        Task {
            await nap(flight + 0.1)
            items.removeAll { $0.id == id }
            leaving[id] = nil
            spin[id] = nil
            drop[id] = nil
        }
        if thenKnock {
            await nap(0.25)
            await knock(impatient: true)
        }
    }

    /// Raises a paw over the next card, stares at you, and thinks better of it. For now.
    private func tease() async {
        guard shelf.first != nil else { return }
        busy = true
        defer { busy = false }
        withAnimation(Motion.snappy) { cat.look = 1 }
        await nap(0.35)
        await show(.lift, for: 0.08)
        show(.raise)
        withAnimation(Motion.snappy.delay(0.2)) { cat.look = 0 }
        await nap(1.3)
        await show(.lift, for: 0.08)
        show(.rest)
    }

    /// Shows one drawing of the swat for [seconds].
    private func show(_ frame: ShelfCatFrame, for seconds: Double) async {
        show(frame)
        await nap(seconds)
    }

    /// Swaps to [frame]; the last drawing fades out over it in a blink, like a motion smear.
    private func show(_ frame: ShelfCatFrame) {
        guard frame != cat.frame else { return }
        cat.previous = cat.frame
        cat.frame = frame
        cat.fade = reduceMotion ? 0 : 1
        withAnimation(.easeOut(duration: 0.09)) { cat.fade = 0 }
    }

    private func blink() async {
        cat.eyesClosed = true
        await nap(0.14)
        cat.eyesClosed = false
        if Bool.random() {
            withAnimation(Motion.gentle) { cat.look = [-1, 1].randomElement()! }
            await nap(0.9)
            withAnimation(Motion.gentle) { cat.look = 0 }
        }
    }

    // MARK: - Touches

    private func tap(_ item: Item) {
        touched()
        if item.id == landed {
            pick(item.template)
        } else if let slot = shelf.firstIndex(of: item.id), !busy {
            // Asking for a particular card: it shuffles up to the cat, who knocks it off.
            withAnimation(Motion.bouncy) { shelf.move(fromOffsets: [slot], toOffset: 0) }
            Task {
                await nap(0.3)
                await knock(impatient: true)
            }
        }
    }

    private func touched() { lastTouch = .now }

    // MARK: - Helpers

    /// Puts the next template on the far end of the shelf, going round the library forever.
    private func addToShelf() {
        let template = templates[nextTemplate % templates.count]
        nextTemplate += 1
        let content = store.content(for: EditorDraft(draft: template.draft), id: template.id, size: .small)
        items.append(Item(id: nextID, template: template, content: content))
        shelf.append(nextID)
        nextID += 1
    }

    private func nap(_ seconds: Double) async {
        guard seconds > 0 else { return }
        try? await Task.sleep(for: .seconds(seconds))
    }
}

// MARK: - Pieces

private struct Item: Identifiable {
    let id: Int
    let template: Template
    /// Worked out once, when the card goes on the shelf: the engine is too slow to ask every frame.
    let content: WidgetContent
    var title: String { template.draft.title }
}

private struct Place {
    var center: CGPoint
    var scale: CGFloat
    var rotation: Double
    var opacity: Double = 1
    var isLanded = false
    var isTipping = false
}

private struct Layout {
    var width: CGFloat

    static let height: CGFloat = 340
    static let shelfY: CGFloat = 112
    static let card: CGFloat = 170
    static let mini: CGFloat = 52
    static let gap: CGFloat = 8
    static let catX: CGFloat = 2
    static let catWidth: CGFloat = 114
    static let catHeight = catWidth * ShelfCatArt.shared.box.height / ShelfCatArt.shared.box.width

    /// How many cards fit beside the cat.
    var slots: Int {
        let room = width - Self.catX - Self.catWidth * ShelfCatArt.shared.restEdge - 6
        return max(1, min(4, Int((room + Self.gap) / (Self.mini + Self.gap))))
    }

    /// The middle of shelf slot [index]; slot 0 stands by the cat's front paw, under his swat.
    func slot(_ index: Int) -> CGPoint {
        let first = Self.catX + Self.catWidth * ShelfCatArt.shared.restEdge + 3
        return CGPoint(x: first + Self.mini / 2 + CGFloat(index) * (Self.mini + Self.gap), y: Self.shelfY - Self.mini / 2)
    }

    var landing: CGPoint { CGPoint(x: width / 2, y: Self.shelfY + 46 + Self.card / 2) }
}

/// The steps of the swat, one drawing each (concept/cats/source/shelf_gen.py).
private enum ShelfCatFrame: CaseIterable {
    case rest, lift, raise, swat

    var pose: CatPose {
        switch self {
        case .rest: .shelfRest
        case .lift: .shelfLift
        case .raise: .shelfRaise
        case .swat: .shelfSwat
        }
    }
}

/// What the cat is doing. Gaze animates; frames swap.
private struct CatPoseState {
    var frame = ShelfCatFrame.rest
    /// The drawing just swapped out, fading away over the new one by [fade].
    var previous = ShelfCatFrame.rest
    var fade: Double = 0
    /// Where he looks: -1 left, 0 at you, 1 right (at the cards).
    var look: CGFloat = 0
    var eyesClosed = false
}

/// The cat on the shelf. Swatting is drawn frame by frame, like a cartoon: the drawings swap
/// and each swap gets a tiny settle, rather than any limb being bent in code.
private struct ShelfCat: View {
    var state: CatPoseState

    var body: some View {
        ZStack {
            drawing(state.frame)
            if state.fade > 0 {
                drawing(state.previous).opacity(state.fade)
            }
        }
        .keyframeAnimator(initialValue: 1.0, trigger: state.frame) { view, squash in
            view.scaleEffect(x: 2 - squash, y: squash, anchor: .bottom)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(0.985, duration: 0.05)
                SpringKeyframe(1, duration: 0.2, spring: .bouncy)
            }
        }
        .accessibilityHidden(true)
    }

    private func drawing(_ frame: ShelfCatFrame) -> some View {
        let art = ShelfCatArt.shared
        return ZStack {
            ForEach(Array(art.layers(of: frame).enumerated()), id: \.offset) { _, item in
                let (layer, path) = item
                ArtShape(path: path, box: art.box, shift: layer.followsGaze ? state.look * art.lookReach(frame) : 0)
                    .fill(layer == .whiskersIn ? Palette.paper : layer.color)
                    .scaleEffect(y: state.eyesClosed && layer.blinks ? 0.08 : 1, anchor: art.eyeLine)
            }
        }
    }
}

/// The frames' layers, built once, and one box that fits all of them so they line up.
private struct ShelfCatArt {
    static let shared = ShelfCatArt()

    let box: CGRect
    /// The resting cat's front paws, as a share of the box's width: the cards start there.
    let restEdge: CGFloat
    /// The eyes' middle, as a share of the box: blinks squash towards it.
    let eyeLine: UnitPoint
    private let cache: [ShelfCatFrame: [(CatLayer, Path)]]

    init() {
        var cache: [ShelfCatFrame: [(CatLayer, Path)]] = [:]
        for frame in ShelfCatFrame.allCases {
            cache[frame] = CatLayer.allCases.compactMap { layer in
                let paths = frame.pose.paths(layer)
                guard !paths.isEmpty else { return nil }
                var path = Path()
                paths.forEach { path.addPath($0) }
                return (layer, path)
            }
        }
        // The rest drawing shows only the far front leg (the near one is the leg that lifts).
        // A copy of it, set a little forward with a hairline between, stands in for the near one.
        var rest = Path()
        CatPose.shelfRest.paths(.body).forEach { rest.addPath($0) }
        var region = Path()
        region.addLines([
            CGPoint(x: 828, y: 548), CGPoint(x: 990, y: 548), CGPoint(x: 990, y: 730), CGPoint(x: 828, y: 730),
            CGPoint(x: 826, y: 590),
        ])
        region.closeSubpath()
        let forward = CGAffineTransform(translationX: 38, y: 0)
        // Where the near leg leaves the chest: its front edge carries on down from the chest's curve.
        var shoulder = Path()
        shoulder.move(to: CGPoint(x: 860, y: 470))
        shoulder.addLine(to: CGPoint(x: 938, y: 470))
        shoulder.addCurve(to: CGPoint(x: 921, y: 560), control1: CGPoint(x: 924, y: 495), control2: CGPoint(x: 920, y: 520))
        shoulder.addLine(to: CGPoint(x: 860, y: 560))
        shoulder.closeSubpath()
        let copied = Path(rest.cgPath.intersection(region.cgPath)).applying(forward)
        let nearLeg = Path(copied.cgPath.union(shoulder.cgPath))
        let edge: [(CGFloat, CGFloat)] = [
            (829, 560), (831, 590), (833, 610), (836, 630), (839, 650), (843, 670), (849, 690), (855, 702),
        ]
        var line = Path()
        line.addLines(edge.map { CGPoint(x: $0.0, y: $0.1) })
        let hairline = Path(line.cgPath.copy(strokingWithWidth: 5, lineCap: .round, lineJoin: .round, miterLimit: 4))
            .applying(forward)
        var layers = cache[.rest] ?? []
        if let body = layers.firstIndex(where: { $0.0 == .body }) {
            layers.insert((.whiskersIn, hairline), at: body + 1)
            layers.insert((.body, nearLeg), at: body + 1)
        }
        cache[.rest] = layers
        self.cache = cache

        var all = Path()
        cache.values.flatMap { $0 }.forEach { all.addPath($0.1) }
        box = all.boundingRect
        var restBody = Path()
        layers.filter { $0.0 == .body }.forEach { restBody.addPath($0.1) }
        restEdge = (restBody.boundingRect.maxX - box.minX) / box.width
        var eyes = Path()
        CatPose.shelfRest.paths(.eyes).forEach { eyes.addPath($0) }
        let eye = eyes.boundingRect
        eyeLine = UnitPoint(x: (eye.midX - box.minX) / box.width, y: (eye.midY - box.minY) / box.height)
    }

    func layers(of frame: ShelfCatFrame) -> [(CatLayer, Path)] { cache[frame] ?? [] }
    func lookReach(_ frame: ShelfCatFrame) -> CGFloat { frame.pose.lookReach }
}

/// Fits part of the art into the frame the same way the whole cat is fitted.
private func fit(_ box: CGRect, in rect: CGRect) -> CGAffineTransform {
    let scale = rect.width / box.width
    return CGAffineTransform(translationX: rect.minX, y: rect.minY)
        .scaledBy(x: scale, y: scale)
        .translatedBy(x: -box.minX, y: -box.minY)
}

private struct ArtShape: Shape {
    var path: Path
    var box: CGRect
    /// Slides sideways, in art units: the pupils following the gaze.
    var shift: CGFloat = 0

    var animatableData: CGFloat {
        get { shift }
        set { shift = newValue }
    }

    func path(in rect: CGRect) -> Path {
        path.applying(CGAffineTransform(translationX: shift, y: 0).concatenating(fit(box, in: rect)))
    }
}

private extension CatLayer {
    var followsGaze: Bool { self == .pupils || self == .highlights }
    var blinks: Bool { self == .eyes || self == .pupils || self == .highlights }
}

/// A plain ink shelf on two brackets, running the width of the scene.
private struct ShelfPlank: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Palette.ink)
                    .frame(width: w, height: 9)
                ForEach([0.18, 0.82], id: \.self) { at in
                    Bracket()
                        .fill(Palette.ink)
                        .frame(width: 18, height: 18)
                        .offset(x: w * at - 9, y: 8)
                }
            }
        }
    }
}

private struct Bracket: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX + 2, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX - 2, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
