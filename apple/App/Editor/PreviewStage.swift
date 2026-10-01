import SwiftUI

/// The live widget preview at the top of the editor: a carousel you swipe through
/// Small → Medium → Lock Screen. Every edit redraws it straight away.
/// Pages tilt away as they leave, the card floats, and it bounces when its look changes.
struct PreviewStage: View {
    @Bindable var model: EditorViewModel
    /// 0…1: how far the preview has shrunk to make room for the form.
    var collapse: Double = 0

    /// Height with nothing scrolled: top gap, carousel, pager, bottom gap.
    static let fullHeight: CGFloat = 8 + 214 + 10 + 40 + 12
    /// How much it can give up: the pager fades out and the card shrinks to 68%.
    static let maxShrink: CGFloat = 40 + 10 + 214 * 0.32

    @State private var width: CGFloat = 360
    @State private var page: CardSize?
    @State private var bounces = 0

    /// How much of the stage each side leaves for the neighbouring sizes to peek in.
    private static let peek: CGFloat = 40

    var body: some View {
        let pageWidth = max(width - Self.peek * 2, 200)
        VStack(spacing: 10) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(Array(model.sizes.enumerated()), id: \.element) { index, size in
                        PreviewPage(model: model, size: size, width: pageWidth, bounces: bounces)
                            .frame(width: pageWidth, height: 214)
                            .contentShape(Rectangle())
                            // Tap a peeking neighbour to bring it to the middle.
                            .onTapGesture {
                                if size != page { withAnimation(Motion.gentle) { page = size } }
                            }
                            .scrollTransition(.interactive, axis: .horizontal) { view, phase in
                                view
                                    // Pull neighbours in, so their edge peeks in at the side without overlapping the card in the middle.
                                    .offset(x: phase.value * pull(index: index, side: phase.value, pageWidth: pageWidth))
                                    .scaleEffect(1 - abs(phase.value) * (1 - Self.neighbourScale))
                                    .rotation3DEffect(.degrees(phase.value * -18), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                                    .opacity(1 - abs(phase.value) * 0.5)
                                    .blur(radius: abs(phase.value) * 1.5)
                            }
                            .zIndex(size == page ? 1 : 0)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, Self.peek, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $page)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            // A horizontal ScrollView takes all the height it's offered; keep it to one page.
            .frame(height: 214)
            .scaleEffect(1 - collapse * 0.32, anchor: .top)

            Pager(sizes: model.sizes, current: page ?? model.previewSize) { size in
                withAnimation(Motion.gentle) { page = size }
            }
            .frame(height: 40)
            // Fades out in the first bit of scrolling, as its space is taken.
            .opacity(max(0, 1 - collapse * 3))
            .scaleEffect(1 - min(collapse * 3, 1) * 0.1)
            .allowsHitTesting(collapse < 0.1)
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { width = $0 }
        .onAppear {
            #if DEBUG
            // For automated screenshots: open on another page.
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--preview-medium") { model.previewSize = .medium }
            if arguments.contains("--preview-lock") { model.previewSize = .rectangular }
            #endif
            page = model.previewSize
        }
        .onChange(of: page) { _, size in
            if let size, size != model.previewSize { model.previewSize = size }
        }
        // The model can switch size too (a wide style moves to Medium): glide there.
        .onChange(of: model.previewSize) { _, size in
            if page != size { withAnimation(Motion.gentle) { page = size } }
        }
        .onChange(of: lookKey) { bounces += 1 }
        .sensoryFeedback(.selection, trigger: page)
    }

    /// How far a neighbour moves towards the middle: until it sits a small gap away
    /// from the card next to it, which depends on how wide both cards are.
    private func pull(index: Int, side: Double, pageWidth: CGFloat) -> CGFloat {
        let sizes = model.sizes
        let next = side > 0 ? index - 1 : index + 1
        guard sizes.indices.contains(next) else { return 0 }
        let distance = Self.visualWidth(sizes[next], pageWidth: pageWidth) / 2 + 16
            + Self.visualWidth(sizes[index], pageWidth: pageWidth) / 2 * Self.neighbourScale
        return min(distance - pageWidth, 0)
    }

    private static let neighbourScale: CGFloat = 0.8

    /// The width a size actually takes in the carousel.
    static func visualWidth(_ size: CardSize, pageWidth: CGFloat) -> CGFloat {
        if size.isAccessory { return min(LockScreenPreview.width, pageWidth) }
        return min(size.previewSize.width, pageWidth - 32)
    }

    /// Everything about the look except the date: changing any of it bounces the card.
    private var lookKey: String {
        let draft = model.draft
        return "\(draft.kind)-\(draft.look)-\(draft.theme)-\(draft.period)-\(draft.dotShape)-\(draft.dotUnit)-\(draft.fillPast)"
    }
}

/// One size in the carousel.
private struct PreviewPage: View {
    var model: EditorViewModel
    var size: CardSize
    var width: CGFloat
    var bounces: Int

    var body: some View {
        Group {
            if size.isAccessory {
                LockScreenPreview(model: model)
            } else {
                homeCard
            }
        }
        .floating()
        .keyframeAnimator(initialValue: 1.0, trigger: bounces) { view, scale in
            view.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(0.95, duration: 0.1)
                SpringKeyframe(1.0, duration: 0.45, spring: .bouncy(extraBounce: 0.2))
            }
        }
    }

    private var homeCard: some View {
        let frame = size.previewSize
        let fit = min(1, (width - 32) / frame.width)
        return TimelineView(.everyMinute) { _ in
            LiveCard(content: model.content(size: size), size: size)
                .frame(width: frame.width, height: frame.height)
                .overlay(alignment: .topTrailing) {
                    if model.phase == .saved {
                        HoppingCat(size: 46).offset(x: -26, y: -38)
                    }
                }
                .shadow(color: Palette.ink.opacity(0.18), radius: 18, y: 10)
                .scaleEffect(fit)
        }
    }
}

/// The size name and dots under the carousel. The current dot stretches; dots are tappable.
private struct Pager: View {
    var sizes: [CardSize]
    var current: CardSize
    var select: (CardSize) -> Void

    var body: some View {
        VStack(spacing: 7) {
            Text(current.label)
                .font(.rounded(13, .heavy))
                .foregroundStyle(Palette.ink.opacity(0.6))
                .id(current)
                .transition(.blurReplace.combined(with: .offset(y: 4)))
            HStack(spacing: 6) {
                ForEach(sizes, id: \.self) { size in
                    Capsule()
                        .fill(Palette.ink.opacity(size == current ? 0.9 : 0.2))
                        .frame(width: size == current ? 20 : 7, height: 7)
                        .padding(4)
                        .contentShape(Rectangle())
                        .onTapGesture { select(size) }
                        .accessibilityLabel(size.label)
                        .accessibilityAddTraits(size == current ? .isSelected : [])
                }
            }
        }
        .motion(Motion.bouncy, value: current)
    }
}

/// Inline, circular and rectangular widgets on a dark lock screen under the clock.
struct LockScreenPreview: View {
    var model: EditorViewModel
    /// Two widgets and the gaps around them; the preview never gets wider than this.
    static let width: CGFloat = 76 + 10 + 172 + 32

    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(spacing: 2) {
                LiveCard(content: model.content(size: .inline), size: .inline)
                    .frame(width: 230, height: 22)
                Text(context.date, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .contentTransition(.numericText())
                HStack(spacing: 10) {
                    LiveCard(content: model.content(size: .circular), size: .circular)
                        .frame(width: 76, height: 76)
                    LiveCard(content: model.content(size: .rectangular), size: .rectangular)
                        .frame(width: 172, height: 76)
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(width: Self.width)
            .background(
                LinearGradient(colors: [Color(hex: 0x3A2A1E), Color(hex: 0x14110F)], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
            )
            .shadow(color: Palette.ink.opacity(0.25), radius: 18, y: 10)
            .environment(\.colorScheme, .dark)
        }
    }
}

private extension View {
    /// A slow bob, so the preview feels alive. Still with Reduce Motion.
    func floating() -> some View { modifier(Floating()) }
}

private struct Floating: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.phaseAnimator(reduceMotion ? [0.0] : [0.0, 1.0]) { view, phase in
            view.offset(y: -4 * phase)
        } animation: { _ in
            .easeInOut(duration: 2.4)
        }
    }
}

extension CardSize {
    var label: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .circular, .rectangular, .inline: "Lock Screen"
        }
    }
}
