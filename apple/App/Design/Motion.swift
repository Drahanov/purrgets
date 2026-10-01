import SwiftUI

/// The app's motion tokens. Every animation uses one of these, so the app moves as one thing.
enum Motion {
    /// Taps, selections, toggles.
    static let snappy = Animation.snappy(duration: 0.28)
    /// Things arriving: cards, menus, the cat.
    static let bouncy = Animation.bouncy(duration: 0.5, extraBounce: 0.12)
    /// Rings, bars and dots filling up.
    static let fill = Animation.smooth(duration: 0.9)
    /// Layout changes: preview size, colour, style.
    static let gentle = Animation.smooth(duration: 0.45)

    /// A small delay per item, so lists arrive as a wave.
    static func stagger(_ index: Int, step: Double = 0.045) -> Double {
        Double(min(index, 12)) * step
    }
}

extension View {
    /// Reduce Motion turns movement into a plain fade.
    func motion<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(MotionModifier(animation: animation, value: value))
    }
}

private struct MotionModifier<V: Equatable>: ViewModifier {
    var animation: Animation
    var value: V
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? .easeInOut(duration: 0.2) : animation, value: value)
    }
}

/// Buttons and cards squish a little under the finger.
struct SquishStyle: ButtonStyle {
    var scale: CGFloat = 0.95

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(Motion.snappy, value: configuration.isPressed)
    }
}

/// Shakes sideways each time [trigger] changes: for a missing title.
struct Shake: ViewModifier {
    var trigger: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, x in
            view.offset(x: x)
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(-12, duration: 0.08)
                SpringKeyframe(10, duration: 0.08)
                SpringKeyframe(-6, duration: 0.08)
                SpringKeyframe(0, duration: 0.2)
            }
        }
    }
}

/// Arrives from below with a spring, [index] places it in a wave.
struct ArriveModifier: ViewModifier {
    var index: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown || reduceMotion ? 1 : 0.92)
            .offset(y: shown || reduceMotion ? 0 : 24)
            .onAppear {
                withAnimation(Motion.bouncy.delay(Motion.stagger(index))) { shown = true }
            }
    }
}

extension View {
    func arrive(_ index: Int = 0) -> some View { modifier(ArriveModifier(index: index)) }
    func shake(_ trigger: Int) -> some View { modifier(Shake(trigger: trigger)) }
}
