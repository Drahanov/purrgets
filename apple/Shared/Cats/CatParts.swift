import SwiftUI

// The cat art: one black cat in six poses, from concept/cats (see its README).
// CatArtData.swift holds the paths; this file parses them and draws them, stretched if needed.

enum CatLayer: CaseIterable {
    case body, paws, eyes, pupils, highlights, nose, whiskers, whiskersIn

    var color: Color {
        switch self {
        case .body, .paws, .pupils: Palette.ink
        case .eyes, .highlights: .white
        case .nose: Palette.nose
        case .whiskers: Palette.whisker
        case .whiskersIn: Palette.whiskerOnInk
        }
    }
}

/// One drawing, in its own units (the SVG viewBox).
struct CatPose {
    let size: CGSize
    let layers: [(CatLayer, [Path])]

    /// How far the pupils can slide sideways and stay inside the eyes, in pose units.
    let lookReach: CGFloat

    init(width: CGFloat, height: CGFloat, layers: [(CatLayer, [String])]) {
        size = CGSize(width: width, height: height)
        self.layers = layers.map { layer, paths in (layer, paths.map(Self.parse)) }
        let eyes = self.layers.filter { $0.0 == .eyes }.flatMap(\.1).map(\.boundingRect)
        let pupils = self.layers.filter { $0.0 == .pupils }.flatMap(\.1).map(\.boundingRect)
        // For each pupil, the room left in the smallest eye around it.
        let room = pupils.compactMap { pupil in
            eyes.filter { $0.contains(CGPoint(x: pupil.midX, y: pupil.midY)) }
                .map { min(pupil.minX - $0.minX, $0.maxX - pupil.maxX) }
                .min()
        }
        lookReach = max(room.min() ?? 0, 0) * 0.85
    }

    func paths(_ layer: CatLayer) -> [Path] {
        layers.filter { $0.0 == layer }.flatMap(\.1)
    }

    /// Reads the generator's format: absolute M/L/C/Z commands, everything space-separated.
    private static func parse(_ data: String) -> Path {
        var path = Path()
        var tokens = data.split(separator: " ")[...]
        func point() -> CGPoint {
            let x = Double(tokens.popFirst()!)!
            let y = Double(tokens.popFirst()!)!
            return CGPoint(x: x, y: y)
        }
        while let command = tokens.popFirst() {
            switch command {
            case "M": path.move(to: point())
            case "L": path.addLine(to: point())
            case "C":
                let c1 = point(), c2 = point()
                path.addCurve(to: point(), control1: c1, control2: c2)
            default: path.closeSubpath()
            }
        }
        return path
    }
}

/// How a pose is bent, in pose units. Zero is the drawing as is.
struct CatWarp: Equatable {
    struct Zone: Equatable {
        var from: CGFloat
        var to: CGFloat
    }

    /// Stretch zones from concept/cats/README.md.
    static let lyingZone = Zone(from: 440, to: 960)
    static let walkingZone = Zone(from: 510, to: 690)
    static let hangingZone = Zone(from: 480, to: 1360)
    static let tallZone = Zone(from: 460, to: 620)

    var x: Zone?
    var y: Zone?
    /// Units added to the x zone (negative squeezes it).
    var stretchX: CGFloat = 0
    /// Units added to the y zone.
    var stretchY: CGFloat = 0

    func apply(_ p: CGPoint) -> CGPoint {
        var p = p
        if let x { p.x = Self.stretch(p.x, x, stretchX) }
        if let y { p.y = Self.stretch(p.y, y, stretchY) }
        return p
    }

    private static func stretch(_ v: CGFloat, _ zone: Zone, _ extra: CGFloat) -> CGFloat {
        if v <= zone.from { return v }
        if v >= zone.to { return v + extra }
        return zone.from + (v - zone.from) * (1 + extra / (zone.to - zone.from))
    }
}

extension CatWarp: VectorArithmetic {
    static var zero: CatWarp { CatWarp() }

    static func + (a: CatWarp, b: CatWarp) -> CatWarp {
        CatWarp(x: a.x ?? b.x, y: a.y ?? b.y, stretchX: a.stretchX + b.stretchX, stretchY: a.stretchY + b.stretchY)
    }

    static func - (a: CatWarp, b: CatWarp) -> CatWarp {
        CatWarp(x: a.x ?? b.x, y: a.y ?? b.y, stretchX: a.stretchX - b.stretchX, stretchY: a.stretchY - b.stretchY)
    }

    mutating func scale(by rhs: Double) {
        stretchX *= rhs
        stretchY *= rhs
    }

    var magnitudeSquared: Double {
        Double(stretchX * stretchX + stretchY * stretchY)
    }
}

/// Draws a pose fitted into its frame (keeping its shape), pinned to [anchor].
/// Warp changes animate: each layer is an animatable Shape.
struct CatArt: View {
    var pose: CatPose
    var warp = CatWarp()
    var eyesClosed = false
    /// Where the pupils point: -1 left, 0 ahead, 1 right. Animates.
    var look: CGFloat = 0
    var hidden: Set<CatLayer> = []
    var anchor: UnitPoint = .bottom

    var body: some View {
        let shown = CatLayer.allCases.filter { !hidden.contains($0) && !(eyesClosed && $0.isOpenEye) }
        ZStack {
            ForEach(shown, id: \.self) { layer in
                CatLayerShape(pose: pose, layer: layer, warp: warp, look: layer.follows ? look : 0, hidden: hidden, anchor: anchor)
                    .fill(layer.color)
            }
            if eyesClosed {
                CatLayerShape(pose: pose, layer: .eyes, warp: warp, hidden: hidden, anchor: anchor, closed: true)
                    .fill(.white)
            }
        }
        .accessibilityHidden(true)
    }

    /// Width over height of what's drawn, so callers can size the frame to fit snugly.
    static func aspect(_ pose: CatPose, warp: CatWarp = CatWarp(), hidden: Set<CatLayer> = []) -> CGFloat {
        let box = CatLayerShape.bounds(pose, warp, hidden)
        return box.width / box.height
    }
}

private extension CatLayer {
    var isOpenEye: Bool { self == .eyes || self == .pupils || self == .highlights }
    /// Moves with the gaze.
    var follows: Bool { self == .pupils || self == .highlights }
}

private struct CatLayerShape: Shape {
    var pose: CatPose
    var layer: CatLayer
    var warp: CatWarp
    /// Slides the layer sideways by this share of the pose's lookReach.
    var look: CGFloat = 0
    var hidden: Set<CatLayer>
    var anchor: UnitPoint
    /// Draws the eyes as sleepy arcs instead.
    var closed = false

    var animatableData: AnimatablePair<CatWarp, CGFloat> {
        get { AnimatablePair(warp, look) }
        set { (warp, look) = (newValue.first, newValue.second) }
    }

    func path(in rect: CGRect) -> Path {
        let box = Self.bounds(pose, warp, hidden)
        guard box.width > 0, box.height > 0 else { return Path() }
        let scale = min(rect.width / box.width, rect.height / box.height)
        let origin = CGPoint(
            x: rect.minX + (rect.width - box.width * scale) * anchor.x - box.minX * scale,
            y: rect.minY + (rect.height - box.height * scale) * anchor.y - box.minY * scale
        )
        let place = CGAffineTransform(translationX: origin.x, y: origin.y).scaledBy(x: scale, y: scale)
            .translatedBy(x: look * pose.lookReach, y: 0)
        var out = Path()
        for path in pose.paths(layer) {
            let bent = Self.bend(path, warp)
            out.addPath(closed ? Self.sleepyArc(bent.boundingRect) : bent, transform: place)
        }
        return out
    }

    /// A ‿ across the lower half of an eye.
    private static func sleepyArc(_ eye: CGRect) -> Path {
        var arc = Path()
        arc.move(to: CGPoint(x: eye.minX, y: eye.midY))
        arc.addQuadCurve(to: CGPoint(x: eye.maxX, y: eye.midY), control: CGPoint(x: eye.midX, y: eye.maxY + eye.height * 0.2))
        return arc.strokedPath(StrokeStyle(lineWidth: max(eye.height * 0.16, 1), lineCap: .round))
    }

    static func bend(_ path: Path, _ warp: CatWarp) -> Path {
        if warp == CatWarp() { return path }
        var out = Path()
        path.forEach { element in
            switch element {
            case .move(let p): out.move(to: warp.apply(p))
            case .line(let p): out.addLine(to: warp.apply(p))
            case .quadCurve(let p, let c): out.addQuadCurve(to: warp.apply(p), control: warp.apply(c))
            case .curve(let p, let c1, let c2): out.addCurve(to: warp.apply(p), control1: warp.apply(c1), control2: warp.apply(c2))
            case .closeSubpath: out.closeSubpath()
            }
        }
        return out
    }

    /// The bent drawing's bounds, from every visible layer, so all layers share one placement.
    static func bounds(_ pose: CatPose, _ warp: CatWarp, _ hidden: Set<CatLayer>) -> CGRect {
        var all = Path()
        for (layer, paths) in pose.layers where !hidden.contains(layer) {
            for path in paths { all.addPath(bend(path, warp)) }
        }
        return all.boundingRect
    }
}

/// The cat peeking over an edge (head and paws), used by the app's moving cats.
struct CatHead: View {
    /// Width of the head itself; paws and whiskers reach a little past it.
    var width: CGFloat
    var asleep = false

    var body: some View {
        let frameWidth = width * 1.3
        CatArt(pose: .peek, eyesClosed: asleep)
            .frame(width: frameWidth, height: frameWidth / CatArt.aspect(.peek))
    }
}
