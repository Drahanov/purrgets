import SwiftUI

// Cats that live in the app. Widgets can't animate, so this is where the cats get to move.
// They draw the same cat art as the widgets (Shared/Cats).

/// A cat head that blinks now and then, glances around and hops when tapped.
struct BlinkingCat: View {
    var size: CGFloat = 44
    @State private var hops = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.18)) { context in
            CatHead(width: size, asleep: isBlinking(at: context.date))
                .rotationEffect(.degrees(tilt(at: context.date)), anchor: .bottom)
                .animation(Motion.gentle, value: tilt(at: context.date))
        }
        .frame(width: size * 1.3, height: size * 1.2)
        .keyframeAnimator(initialValue: HopFrame(), trigger: hops) { view, frame in
            view
                .scaleEffect(x: frame.stretch, y: 1 / frame.stretch, anchor: .bottom)
                .offset(y: frame.lift)
        } keyframes: { _ in
            KeyframeTrack(\.lift) {
                SpringKeyframe(0, duration: 0.08)
                CubicKeyframe(-size * 0.45, duration: 0.18)
                SpringKeyframe(0, duration: 0.35, spring: .bouncy)
            }
            KeyframeTrack(\.stretch) {
                CubicKeyframe(0.86, duration: 0.08)
                CubicKeyframe(1.08, duration: 0.18)
                SpringKeyframe(1, duration: 0.35, spring: .bouncy)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { hops += 1 }
        .sensoryFeedback(.impact(weight: .light), trigger: hops)
        .accessibilityHidden(true)
    }

    /// Blinks for one tick about every 4 seconds; never with Reduce Motion.
    private func isBlinking(at date: Date) -> Bool {
        guard !reduceMotion else { return false }
        let ticks = Int(date.timeIntervalSinceReferenceDate / 0.18)
        return ticks % 23 == 0 || ticks % 97 == 2
    }

    /// A slow head tilt, changing every ~3 seconds.
    private func tilt(at date: Date) -> Double {
        guard !reduceMotion else { return 0 }
        let step = Int(date.timeIntervalSinceReferenceDate / 3) % 4
        return [0, -7, 0, 6][step]
    }
}

struct HopFrame {
    var lift: CGFloat = 0
    var stretch: CGFloat = 1
}

/// The empty-state cat: lying asleep, with z's floating away.
struct SleepingCat: View {
    var size: CGFloat = 120

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CatArt(pose: .lying, eyesClosed: true)
                .frame(width: size, height: size / CatArt.aspect(.lying))
                .phaseAnimator([0.0, 1.0]) { cat, phase in
                    // Breathing.
                    cat.scaleEffect(x: 1 + phase * 0.015, y: 1 + phase * 0.035, anchor: .bottom)
                } animation: { _ in .easeInOut(duration: 1.6) }
            FloatingZs(size: size * 0.16)
                .offset(x: size * 0.05, y: -size * 0.35)
        }
        .foregroundStyle(Palette.ink)
        .frame(width: size * 1.2, height: size * 0.6)
        .accessibilityHidden(true)
    }
}

private struct FloatingZs: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Text("z")
                    .font(.rounded(size * (1 - CGFloat(index) * 0.2), .heavy))
                    .phaseAnimator([0.0, 1.0]) { z, phase in
                        z.offset(x: phase * size * 0.8, y: -phase * size * 2.2)
                            .opacity(phase < 0.5 ? phase * 2 : 2 - phase * 2)
                    } animation: { _ in
                        .easeOut(duration: 2.4).delay(Double(index) * 0.8)
                    }
            }
        }
    }
}

/// Jumps onto a saved card: lands, squashes, then sits there looking pleased.
struct HoppingCat: View {
    var size: CGFloat
    @State private var landed = false

    var body: some View {
        CatHead(width: size)
            .keyframeAnimator(initialValue: HopFrame(lift: -size * 3, stretch: 1), trigger: landed) { view, frame in
                view
                    .scaleEffect(x: frame.stretch, y: 1 / frame.stretch, anchor: .bottom)
                    .offset(y: frame.lift)
            } keyframes: { _ in
                KeyframeTrack(\.lift) {
                    CubicKeyframe(-size * 3, duration: 0.01)
                    CubicKeyframe(0, duration: 0.28)
                    CubicKeyframe(-size * 0.25, duration: 0.14)
                    SpringKeyframe(0, duration: 0.3, spring: .bouncy)
                }
                KeyframeTrack(\.stretch) {
                    CubicKeyframe(0.9, duration: 0.29)
                    CubicKeyframe(1.3, duration: 0.08)
                    SpringKeyframe(1, duration: 0.45, spring: .bouncy)
                }
            }
            .onAppear { landed = true }
            .accessibilityHidden(true)
    }
}
