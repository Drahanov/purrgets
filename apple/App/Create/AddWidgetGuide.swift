import SwiftUI

/// After the first save: apps can't add widgets themselves, so we act it out.
/// A drawn iPhone or Mac plays every step with a finger or a cursor, using the user's own card.
/// Tap the device to skip ahead, tap a segment of the step bar to jump to it.
struct AddWidgetGuide: View {
    var cards: GuideCards
    var hideForever: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var flow = GuideFlow.ordered[0]
    @State private var player = GuidePlayer()
    @State private var shownStep = 0

    var body: some View {
        VStack(spacing: 14) {
            Text(flow.title)
                .font(.rounded(24, .black))
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .padding(.top, 24)
            if GuideFlow.ordered.count > 1 { FlowPicker(flow: $flow) }
            TimelineView(.animation(paused: player.isPaused)) { timeline in
                let beat = player.beat(in: flow, at: timeline.date)
                VStack(spacing: 14) {
                    stage(beat)
                    StepBar(flow: flow, beat: beat) { player.jump(to: $0, in: flow, settled: reduceMotion) }
                    StepCaption(flow: flow, step: beat.step)
                }
                .onChange(of: beat.step) { _, step in shownStep = step }
            }
            VStack(spacing: 6) {
                InkButton(title: "Got it") { dismiss() }
                Button("Don't show this again") {
                    hideForever()
                    dismiss()
                }
                .font(.rounded(14, .heavy))
                .foregroundStyle(Palette.ink.opacity(0.55))
                .padding(.vertical, 6)
            }
            .frame(maxWidth: 420)
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.paper.ignoresSafeArea())
        .presentationDetents([.large])
        .frame(minWidth: Platform.isMac ? 560 : nil, minHeight: Platform.isMac ? 720 : nil)
        .animation(Motion.gentle, value: flow)
        .sensoryFeedback(.impact(weight: .light), trigger: shownStep)
        .onChange(of: flow) { _, flow in player.restart(in: flow, settled: reduceMotion) }
        .onAppear {
            player.restart(in: flow, settled: reduceMotion)
            debugLaunch()
        }
    }

    private func stage(_ beat: GuideBeat) -> some View {
        DeviceStage(flow: flow, beat: beat, cards: cards)
            .id(flow)
            .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .opacity))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { player.jump(to: beat.step + 1, in: flow, settled: reduceMotion) }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    player.togglePause(in: flow)
                } label: {
                    Image(systemName: player.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.75), in: Circle())
                }
                .buttonStyle(SquishStyle())
                .accessibilityLabel(player.isPaused ? "Play" : "Pause")
            }
            .accessibilityElement(children: .contain)
    }

    private func debugLaunch() {
        #if DEBUG
        // --guide-flow home|lock|mac and --guide-at <seconds> freeze a frame for screenshots.
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--guide-flow"), index + 1 < arguments.count {
            flow = [GuideFlow.homeScreen, .lockScreen, .desktop].first { $0.debugName == arguments[index + 1] } ?? flow
        }
        if let index = arguments.firstIndex(of: "--guide-at"), index + 1 < arguments.count, let seconds = Double(arguments[index + 1]) {
            DispatchQueue.main.async { player.freeze(at: seconds) }
        }
        #endif
    }
}

// MARK: - Flows

struct GuideStep {
    var text: String
    var duration: Double
}

/// The three places a widget can go, each acted out on its own device.
enum GuideFlow: Hashable {
    case homeScreen, lockScreen, desktop

    /// Only this device's own places: trackers don't sync, so the other device's widgets couldn't show them.
    static var ordered: [GuideFlow] {
        Platform.isMac ? [.desktop] : [.homeScreen, .lockScreen]
    }

    var label: String {
        switch self {
        case .homeScreen: "Home Screen"
        case .lockScreen: "Lock Screen"
        case .desktop: "Mac"
        }
    }

    var symbol: String {
        switch self {
        case .homeScreen: "iphone"
        case .lockScreen: "lock.fill"
        case .desktop: "laptopcomputer"
        }
    }

    var title: String {
        switch self {
        case .homeScreen: "Put it on your Home Screen"
        case .lockScreen: "Put it on your Lock Screen"
        case .desktop: "Put it on your desktop"
        }
    }

    var footnote: String? {
        self == .lockScreen ? "For a one-line widget, tap the date above the clock instead." : nil
    }

    /// Each step's caption and how long the device takes to act it out; the scenes are timed to match.
    var steps: [GuideStep] {
        switch self {
        case .homeScreen: [
            GuideStep(text: "Touch and hold an empty spot until the apps jiggle.", duration: 3.0),
            GuideStep(text: "Tap Edit in the top corner, then Add Widget.", duration: 3.0),
            GuideStep(text: "Find Purrgets in the list and tap it.", duration: 3.0),
            GuideStep(text: "Swipe to the size you like, then tap Add Widget.", duration: 4.0),
            GuideStep(text: "Tap Done. Hold the widget, tap Edit Widget and choose your tracker.", duration: 5.4),
        ]
        case .lockScreen: [
            GuideStep(text: "Touch and hold the Lock Screen, tap Customize, then pick Lock Screen.", duration: 3.8),
            GuideStep(text: "Tap the box under the clock.", duration: 2.4),
            GuideStep(text: "Find Purrgets and tap a widget to add it.", duration: 3.6),
            GuideStep(text: "Tap the widget to choose your tracker, then tap Done.", duration: 4.4),
        ]
        case .desktop: [
            GuideStep(text: "Right-click the desktop and choose Edit Widgets.", duration: 3.0),
            GuideStep(text: "Find Purrgets in the widget gallery.", duration: 2.4),
            GuideStep(text: "Drag a size onto your desktop, then click Done.", duration: 3.8),
            GuideStep(text: "Right-click the widget, choose Edit “Tracker” and pick your tracker.", duration: 4.6),
        ]
        }
    }

    /// The last frame stays up this long before the loop starts again.
    static let rest = 1.6

    var loopLength: Double { steps.map(\.duration).reduce(0, +) + Self.rest }

    func start(of step: Int) -> Double { steps.prefix(step).map(\.duration).reduce(0, +) }

    fileprivate var debugName: String {
        switch self {
        case .homeScreen: "home"
        case .lockScreen: "lock"
        case .desktop: "mac"
        }
    }
}

/// Plays a flow on a loop. Everything is worked out from the clock, so pausing and jumping are just new offsets.
struct GuidePlayer {
    private var start = Date.now
    private var pausedAt: Double?

    var isPaused: Bool { pausedAt != nil }

    func beat(in flow: GuideFlow, at date: Date) -> GuideBeat {
        let steps = flow.steps
        var rest = (pausedAt ?? date.timeIntervalSince(start)).truncatingRemainder(dividingBy: flow.loopLength)
        for (index, step) in steps.enumerated() {
            if rest < step.duration || index == steps.count - 1 {
                return GuideBeat(step: index, t: min(rest, step.duration), clock: date.timeIntervalSinceReferenceDate)
            }
            rest -= step.duration
        }
        return GuideBeat(step: 0, t: 0, clock: 0)
    }

    /// [settled] lands on the end of the step instead of its start: Reduce Motion shows the result, not the motion.
    mutating func jump(to step: Int, in flow: GuideFlow, settled: Bool) {
        let count = flow.steps.count
        let index = (step % count + count) % count
        var offset = flow.start(of: index)
        if settled { offset += flow.steps[index].duration - 0.01 }
        if isPaused || settled { pausedAt = offset } else { start = .now.addingTimeInterval(-offset) }
    }

    mutating func restart(in flow: GuideFlow, settled: Bool) {
        pausedAt = nil
        start = .now
        if settled { jump(to: 0, in: flow, settled: true) }
    }

    mutating func togglePause(in flow: GuideFlow) {
        if let pausedAt {
            start = .now.addingTimeInterval(-pausedAt)
            self.pausedAt = nil
        } else {
            pausedAt = Date.now.timeIntervalSince(start).truncatingRemainder(dividingBy: flow.loopLength)
        }
    }

    mutating func freeze(at seconds: Double) { pausedAt = seconds }
}

// MARK: - Pieces

/// The device for the flow, scaled to whatever room there is.
private struct DeviceStage: View {
    var flow: GuideFlow
    var beat: GuideBeat
    var cards: GuideCards

    var body: some View {
        GeometryReader { geometry in
            let box = flow == .desktop ? MacFrame<EmptyView>.size : PhoneFrame<EmptyView>.size
            let scale = min(geometry.size.width / box.width, geometry.size.height / box.height, 1.5)
            device(for: flow)
                .frame(width: box.width, height: box.height)
                .scaleEffect(scale)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder private func device(for flow: GuideFlow) -> some View {
        switch flow {
        case .homeScreen: PhoneFrame { HomeScreenScene(beat: beat, cards: cards) }
        case .lockScreen: PhoneFrame { LockScreenScene(beat: beat, cards: cards) }
        case .desktop: MacFrame { MacDesktopScene(beat: beat, cards: cards) }
        }
    }
}

/// Home Screen / Lock Screen / Mac.
private struct FlowPicker: View {
    @Binding var flow: GuideFlow
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(GuideFlow.ordered, id: \.self) { option in
                Button {
                    flow = option
                } label: {
                    Label(option.label, systemImage: option.symbol)
                        .font(.rounded(13, .heavy))
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(option == flow ? Palette.paper : Palette.ink)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background {
                            if option == flow {
                                Capsule().fill(Palette.ink).matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(SquishStyle())
                .accessibilityAddTraits(option == flow ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Palette.sand.opacity(0.6), in: Capsule())
        .animation(Motion.snappy, value: flow)
    }
}

/// One segment per step, like stories: past ones full, the current one filling as it plays.
private struct StepBar: View {
    var flow: GuideFlow
    var beat: GuideBeat
    var jump: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(flow.steps.enumerated()), id: \.offset) { index, step in
                Button {
                    jump(index)
                } label: {
                    Capsule()
                        .fill(Palette.ink.opacity(0.12))
                        .overlay(alignment: .leading) {
                            GeometryReader { geometry in
                                Capsule().fill(Palette.tangerine).frame(width: geometry.size.width * fill(index, step))
                            }
                        }
                        .frame(height: 5)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Step \(index + 1): \(step.text)")
            }
        }
        .frame(maxWidth: 420)
    }

    private func fill(_ index: Int, _ step: GuideStep) -> CGFloat {
        if index < beat.step { return 1 }
        if index > beat.step { return 0 }
        return CGFloat(min(beat.t / step.duration, 1))
    }
}

/// The current step in words, sliding in as the device moves on.
private struct StepCaption: View {
    var flow: GuideFlow
    var step: Int

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                Text("\(step + 1)")
                    .font(.rounded(14, .black))
                    .frame(width: 28, height: 28)
                    .background(Palette.marigold, in: Circle())
                Text(flow.steps[step].text)
                    .font(.rounded(17, .bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .id("\(flow.label)-\(step)")
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            if let footnote = flow.footnote {
                Text(footnote)
                    .font(.rounded(13, .semibold))
                    .foregroundStyle(Palette.ink.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 40)
            }
        }
        .frame(maxWidth: 420, minHeight: 84, alignment: .top)
        .clipped()
        .animation(Motion.bouncy, value: step)
    }
}
