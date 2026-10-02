import SwiftUI

/// Explains cameos (a cat drops by Number cards now and then) and lets the user turn them off.
/// A mini Number card of this tracker plays through the poses, so the user sees what they get.
struct CatVisitsSection: View {
    var model: EditorViewModel

    private var isNumber: Bool { model.draft.look == .number }

    var body: some View {
        EditorSection(title: "Visitor") {
            HStack(alignment: .center, spacing: 14) {
                CameoReel(content: model.content(look: .number), on: model.draft.cameos)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.draft.cameos ? "Mr Joe Long" : "Mr Joe Long is out")
                        .font(.rounded(17, .black))
                        .contentTransition(.opacity)
                    Text("We don't like him. He bothers us. But we let him swing by your Number widget now and then: hanging off the top, strolling past, waving his tail. Poke him if you must.")
                        .font(.rounded(13, .bold))
                        .foregroundStyle(Palette.ink.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Toggle(isOn: cameos) {
                Text("Let him swing by").font(.rounded(15, .heavy))
            }
            .toggleStyle(.switch)
            if !isNumber && model.draft.cameos {
                HStack(spacing: 8) {
                    Label("He only bothers Number cards", systemImage: "info.circle.fill")
                        .font(.rounded(13, .heavy))
                        .foregroundStyle(Palette.ink.opacity(0.55))
                    Spacer(minLength: 0)
                    Button("Use Number") {
                        withAnimation(Motion.bouncy) { model.setLook(.number) }
                    }
                    .font(.rounded(13, .heavy))
                    .buttonStyle(SquishStyle(scale: 0.92))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .foregroundStyle(Palette.ink)
        .motion(Motion.snappy, value: model.draft.cameos)
        .motion(Motion.snappy, value: isNumber)
        .sensoryFeedback(.selection, trigger: model.draft.cameos)
    }

    private var cameos: Binding<Bool> {
        Binding(get: { model.draft.cameos }, set: { model.draft.cameos = $0 })
    }
}

/// A small Number card whose cat changes pose every couple of seconds (the widget does it every 5 minutes).
private struct CameoReel: View {
    var content: WidgetContent
    var on: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let poses = WidgetContent.Cameo.Pose.allCases
    private static let step = 2.2

    var body: some View {
        TimelineView(.periodic(from: .now, by: Self.step)) { context in
            LiveCard(content: card(at: context.date), size: .small)
                .frame(width: 170, height: 170)
                .scaleEffect(0.6)
                .frame(width: 102, height: 102)
        }
        .accessibilityHidden(true)
    }

    private func card(at date: Date) -> WidgetContent {
        var card = content
        card.cameo = on ? cameo(at: date) : nil
        return card
    }

    private func cameo(at date: Date) -> WidgetContent.Cameo {
        guard !reduceMotion else { return .init(pose: .paws) }
        let tick = Int(date.timeIntervalSinceReferenceDate / Self.step)
        return .init(
            pose: Self.poses[tick % Self.poses.count],
            look: [0, -1, 1][tick % 3]
        )
    }
}
