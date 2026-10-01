import SwiftUI

/// The long cat lying along a track. Its body reaches [fraction] of the way to the fish.
struct LongCatView: View {
    var fraction: Double

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let fishWidth = h * 0.7
            let shortest = h * 1.9
            let room: CGFloat = geo.size.width - shortest - fishWidth - 6
            let length = shortest + room * CGFloat(min(max(fraction, 0), 1))
            let thickness = h * 0.34
            let head = h * 0.56
            let bodyY = h * 0.58

            ZStack(alignment: .topLeading) {
                Tail()
                    .frame(width: h * 0.42, height: h * 0.55)
                    .offset(x: 0, y: bodyY - h * 0.5)
                // Body: the only part that stretches.
                Capsule()
                    .frame(width: length - head * 0.5 - h * 0.25, height: thickness)
                    .offset(x: h * 0.25, y: bodyY - thickness / 2)
                // Legs.
                ForEach([h * 0.35, length - head * 0.75], id: \.self) { x in
                    Capsule()
                        .frame(width: thickness * 0.5, height: h * 0.3)
                        .offset(x: x, y: bodyY)
                }
                CatHead(width: head)
                    .offset(x: length - head, y: bodyY - head * 0.95)
                Fish()
                    .frame(width: fishWidth, height: fishWidth * 0.5)
                    .opacity(0.55)
                    .offset(x: geo.size.width - fishWidth, y: bodyY - fishWidth * 0.25)
            }
            .foregroundStyle(Palette.ink)
        }
    }
}

/// The fat cat sitting, front view. [growth] 0…1 makes it rounder.
struct FatCatView: View {
    var growth: Double

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let bodyHeight = h * 0.8
            let bodyWidth = bodyHeight * (0.62 + 0.42 * min(max(growth, 0), 1))
            ZStack(alignment: .bottom) {
                Tail()
                    .scaleEffect(x: -1)
                    .frame(width: bodyHeight * 0.32, height: bodyHeight * 0.45)
                    .offset(x: bodyWidth * 0.52, y: -bodyHeight * 0.05)
                HStack(spacing: bodyWidth * 0.3) {
                    Ear().frame(width: bodyHeight * 0.2, height: bodyHeight * 0.2)
                    Ear().scaleEffect(x: -1).frame(width: bodyHeight * 0.2, height: bodyHeight * 0.2)
                }
                .offset(y: -bodyHeight * 0.88)
                Ellipse()
                    .frame(width: bodyWidth, height: bodyHeight)
                CatFace(size: bodyHeight * 0.5)
                    .offset(y: -bodyHeight * 0.58)
                // Paws: thin cream lines (DESIGN.md).
                HStack(spacing: bodyWidth * 0.16) {
                    pawLine(bodyHeight)
                    pawLine(bodyHeight)
                }
                .offset(y: -bodyHeight * 0.06)
            }
            .foregroundStyle(Palette.ink)
            .frame(width: geo.size.width, height: h, alignment: .bottom)
        }
    }

    private func pawLine(_ size: CGFloat) -> some View {
        Capsule().fill(Palette.cream).frame(width: max(1.5, size * 0.02), height: size * 0.16)
    }
}

/// A cat visiting a card. Draws over the whole card; the card clips it at the edges.
struct CameoView: View {
    var cameo: WidgetContent.Cameo

    var body: some View {
        GeometryReader { geo in
            let unit = min(geo.size.width, geo.size.height)
            // Smaller on square cards, where the number fills most of the width.
            let head = unit * (geo.size.width > geo.size.height * 1.5 ? 0.36 : 0.28)
            let wide = cameo.cat == .fat
            let w = geo.size.width
            let h = geo.size.height
            ZStack(alignment: .topLeading) {
                switch cameo.pose {
                case .peek:
                    CatHead(width: head, wide: wide)
                        .position(x: w - head * 0.6, y: h - head * 0.16)
                case .ears:
                    HStack(spacing: head * 0.34) {
                        Ear().frame(width: head * 0.32, height: head * 0.32)
                        Ear().scaleEffect(x: -1).frame(width: head * 0.32, height: head * 0.32)
                    }
                    .position(x: w - head * 0.85, y: h - head * 0.12)
                case .paws:
                    HStack(spacing: head * 0.3) {
                        paw(head)
                        paw(head)
                    }
                    .position(x: w - head * 0.62, y: head * 0.12)
                case .tail:
                    // Swishes in from the right edge, curling up.
                    Tail(thickness: 0.2)
                        .frame(width: head * 0.8, height: head * 1.2)
                        .position(x: w - head * 0.15, y: h - head * 0.62)
                case .sleep:
                    sleepingCat(head * 0.62, wide: wide)
                        .position(x: w - head * 0.62, y: head * 0.36)
                }
            }
            .foregroundStyle(Palette.ink)
        }
        .allowsHitTesting(false)
    }

    private func paw(_ head: CGFloat) -> some View {
        Capsule()
            .frame(width: head * 0.24, height: head * 0.5)
            .overlay(alignment: .bottom) {
                HStack(spacing: head * 0.03) {
                    ForEach(0..<2, id: \.self) { _ in
                        Capsule().fill(Palette.cream).frame(width: 1.2, height: head * 0.07)
                    }
                }
                .padding(.bottom, head * 0.04)
            }
    }

    private func sleepingCat(_ head: CGFloat, wide: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            Capsule()
                .frame(width: head * 1.5, height: head * 0.55)
                .offset(y: head * 0.25)
            CatHead(width: head * 0.6, wide: wide, asleep: true)
                .offset(x: head * 0.05, y: head * 0.05)
            Text("z")
                .font(.rounded(head * 0.28, .heavy))
                .offset(x: head * 0.3, y: -head * 0.3)
        }
        .frame(width: head * 1.6, height: head * 0.9)
    }
}
