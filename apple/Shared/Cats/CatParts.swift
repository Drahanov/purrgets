import SwiftUI

// Placeholder cats: flat black silhouettes with a tiny face (DESIGN.md).
// The real art replaces these files; the views using them stay the same.

struct Ear: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

/// Two eyes and a nose, sized to a head of [size] width.
struct CatFace: View {
    var size: CGFloat
    var asleep = false

    var body: some View {
        VStack(spacing: size * 0.06) {
            HStack(spacing: size * 0.22) {
                eye
                eye
            }
            Circle()
                .fill(Palette.nose)
                .frame(width: size * 0.1, height: size * 0.08)
        }
    }

    @ViewBuilder private var eye: some View {
        if asleep {
            Capsule().fill(.white).frame(width: size * 0.18, height: size * 0.035)
        } else {
            Circle()
                .fill(.white)
                .frame(width: size * 0.2, height: size * 0.2)
                .overlay(Circle().fill(Palette.ink).frame(width: size * 0.09, height: size * 0.09).offset(x: size * 0.02))
        }
    }
}

/// A cat head with ears, centred in its frame. [width] is the head width.
struct CatHead: View {
    var width: CGFloat
    var wide = false
    var asleep = false

    var body: some View {
        let height = width * (wide ? 0.78 : 0.88)
        ZStack {
            HStack(spacing: width * 0.34) {
                Ear().frame(width: width * 0.3, height: width * 0.3)
                Ear().scaleEffect(x: -1).frame(width: width * 0.3, height: width * 0.3)
            }
            .offset(y: -height * 0.5)
            RoundedRectangle(cornerRadius: width * 0.42, style: .continuous)
                .frame(width: width, height: height)
            CatFace(size: width, asleep: asleep).offset(y: height * 0.05)
            whiskers(height: height)
        }
        .foregroundStyle(Palette.ink)
    }

    private func whiskers(height: CGFloat) -> some View {
        HStack(spacing: width * 0.55) {
            whiskerSide.scaleEffect(x: -1)
            whiskerSide
        }
        .offset(y: height * 0.2)
    }

    private var whiskerSide: some View {
        VStack(spacing: width * 0.07) {
            Capsule().frame(width: width * 0.32, height: max(1, width * 0.025)).rotationEffect(.degrees(-8))
            Capsule().frame(width: width * 0.32, height: max(1, width * 0.025)).rotationEffect(.degrees(8))
        }
        .foregroundStyle(Palette.ink.opacity(0.85))
    }
}

/// A curved tail, drawn up and to the left from the bottom right of its frame.
struct Tail: Shape {
    /// Stroke width as a share of the frame width.
    var thickness: CGFloat = 0.28

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addCurve(
                to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY),
                control1: CGPoint(x: rect.minX, y: rect.maxY),
                control2: CGPoint(x: rect.minX - rect.width * 0.1, y: rect.minY + rect.height * 0.3)
            )
        }
        .strokedPath(StrokeStyle(lineWidth: rect.width * thickness, lineCap: .round))
    }
}

/// A small fish: the finish line for the long cat.
struct Fish: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            let body = CGRect(x: rect.minX + rect.width * 0.3, y: rect.minY, width: rect.width * 0.7, height: rect.height)
            path.addEllipse(in: body)
            path.move(to: CGPoint(x: body.minX + 1, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
