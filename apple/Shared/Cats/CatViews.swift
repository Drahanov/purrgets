import SwiftUI

/// The long cat lying along the card, its nose reaching [fraction] of the way across.
/// Only the middle of the body stretches; tail, legs and head keep their size.
struct LongCatView: View {
    var fraction: Double

    var body: some View {
        GeometryReader { geo in
            let pose = CatPose.lying
            let scale = geo.size.height / pose.size.height
            let zone = CatWarp.lyingZone.to - CatWarp.lyingZone.from
            // Squeezing the zone past half kinks the back, so that's the shortest cat.
            let shortest = (pose.size.width - zone * 0.5) * scale
            let longest = max(shortest, geo.size.width)
            let length = shortest + (longest - shortest) * CGFloat(min(max(fraction, 0), 1))
            let warp = CatWarp(x: CatWarp.lyingZone, stretchX: length / scale - pose.size.width)
            CatArt(pose: pose, warp: warp, anchor: .bottomLeading)
        }
    }
}

/// A cat visiting a card. Draws over the whole card; the card clips it at the edges.
struct CameoView: View {
    var cameo: WidgetContent.Cameo
    /// In a widget: the tracker whose cat reacts to taps (CatPoke). Elsewhere the cat isn't tappable.
    @Environment(\.pokeTrackerID) private var pokeID

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let unit = min(w, h)
            // Smaller on square cards, where the number fills most of the width.
            let wide = w > h * 1.5
            let head = unit * (wide ? 0.36 : 0.28)
            ZStack(alignment: .topLeading) {
                // Group hands the transition to whichever pose is drawn (no .id(): it flashes in widgets).
                Group {
                    switch cameo.pose {
                    case .paws:
                        // Hanging upside down from the top edge.
                        let size = fitted(.peek, width: head * 1.6)
                        tappable(art(.peek, flipped: true)
                            .frame(width: size.width, height: size.height)
                            .rotationEffect(.degrees(180)))
                            .position(x: w - size.width * 0.55, y: size.height * 0.5 - size.height * 0.15)
                    case .tail:
                        // The cat lies off the right edge; only its tail rises into the card.
                        let pose = CatPose.lying
                        let scale = head * 1.7 / pose.size.height
                        tappable(art(pose, anchor: .topLeading)
                            .frame(width: pose.size.width * scale, height: pose.size.height * scale))
                            .offset(x: w - head * 0.75 - 220 * scale, y: h - 470 * scale)
                    case .hang:
                        // Dangling from the top edge by its front paws, nearly to the bottom.
                        // Its width follows the length, so the body is only squeezed a little
                        // (squeezing the stretch zone hard bunches the legs up).
                        let pose = CatPose.hanging
                        let zone = CatWarp.hangingZone.to - CatWarp.hangingZone.from
                        let length = h * 0.95
                        let scale = length / (pose.size.height - zone * 0.25)
                        let width = pose.size.width * scale
                        let warp = CatWarp(y: CatWarp.hangingZone, stretchY: length / scale - pose.size.height)
                        tappable(art(pose, warp: warp, anchor: .topLeading)
                            .frame(width: width, height: length))
                            .position(x: w - width * 0.5 - 16, y: length * 0.5 - length * 0.03)
                    case .walk:
                        // Strolling in from the right edge along the bottom, flipped to face left.
                        let size = fitted(.walking, width: head * 2.6)
                        tappable(art(.walking, flipped: true)
                            .frame(width: size.width, height: size.height)
                            .scaleEffect(x: -1))
                            .position(x: w + size.width * 0.08, y: h - size.height * 0.5 + 2)
                    case .tall:
                        // Standing up, partly behind the right edge.
                        let size = fitted(.tall, width: head)
                        tappable(art(.tall)
                            .frame(width: size.width, height: size.height))
                            .position(x: w - size.width * 0.15, y: h - size.height * 0.5 + 4)
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: cameo.pose.entersFrom), removal: .opacity))
            }
            .animation(.spring(duration: 0.7, bounce: 0.25), value: cameo)
        }
        .allowsHitTesting(pokeID != nil)
    }

    /// Only the cat itself is the button, so taps elsewhere still open the app.
    @ViewBuilder private func tappable(_ cat: some View) -> some View {
        if let pokeID {
            Button(intent: PokeCatIntent(trackerID: pokeID)) { cat }
                .buttonStyle(.plain)
        } else {
            cat
        }
    }

    /// The cat art with this visit's gaze. [flipped] art is drawn mirrored or upside down,
    /// so its gaze is turned around to still point the right way on screen.
    private func art(_ pose: CatPose, warp: CatWarp = CatWarp(), anchor: UnitPoint = .bottom, flipped: Bool = false) -> CatArt {
        CatArt(pose: pose, warp: warp, look: (flipped ? -1 : 1) * cameo.look, anchor: anchor)
    }

    private func fitted(_ pose: CatPose, width: CGFloat, hidden: Set<CatLayer> = []) -> CGSize {
        CGSize(width: width, height: width / CatArt.aspect(pose, hidden: hidden))
    }
}

private extension WidgetContent.Cameo.Pose {
    /// The edge a new pose slides in from.
    var entersFrom: Edge {
        switch self {
        case .paws, .hang: .top
        case .tail, .walk, .tall: .trailing
        }
    }
}
