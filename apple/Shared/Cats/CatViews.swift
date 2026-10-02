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

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let unit = min(w, h)
            // Smaller on square cards, where the number fills most of the width.
            let wide = w > h * 1.5
            let head = unit * (wide ? 0.36 : 0.28)
            ZStack(alignment: .topLeading) {
                switch cameo.pose {
                case .peek:
                    // Head and paws over the bottom edge.
                    // Smaller on square cards, so it stays clear of the number.
                    let size = fitted(.peek, width: head * (wide ? 1.7 : 1.3))
                    CatArt(pose: .peek)
                        .frame(width: size.width, height: size.height)
                        .position(x: w - size.width * 0.5, y: h - size.height * 0.5)
                case .ears:
                    // The ears and eyes show over the bottom edge.
                    let size = fitted(.peek, width: head * 1.7, hidden: [.paws])
                    CatArt(pose: .peek, hidden: [.paws])
                        .frame(width: size.width, height: size.height)
                        .position(x: w - size.width * 0.55, y: h + size.height * 0.5 - size.height * 0.62)
                case .paws:
                    // Hanging upside down from the top edge.
                    let size = fitted(.peek, width: head * 1.6)
                    CatArt(pose: .peek)
                        .frame(width: size.width, height: size.height)
                        .rotationEffect(.degrees(180))
                        .position(x: w - size.width * 0.55, y: size.height * 0.5 - size.height * 0.15)
                case .tail:
                    // The cat lies off the right edge; only its tail rises into the card.
                    let pose = CatPose.lying
                    let scale = head * 1.7 / pose.size.height
                    CatArt(pose: pose, anchor: .topLeading)
                        .frame(width: pose.size.width * scale, height: pose.size.height * scale)
                        .offset(x: w - head * 0.75 - 220 * scale, y: h - 470 * scale)
                case .sleep:
                    // Napping in the top corner.
                    let size = fitted(.lying, width: head * (wide ? 1.9 : 1.5))
                    CatArt(pose: .lying, eyesClosed: true)
                        .frame(width: size.width, height: size.height)
                        .position(x: w - size.width * 0.5 - 8, y: size.height * 0.5 + 8)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func fitted(_ pose: CatPose, width: CGFloat, hidden: Set<CatLayer> = []) -> CGSize {
        CGSize(width: width, height: width / CatArt.aspect(pose, hidden: hidden))
    }
}
