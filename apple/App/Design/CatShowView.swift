import SharedLogic
import SwiftUI
import WidgetKit

/// Every cat we have, moving: the cameos on cards and the six poses.
/// Also switches the cat show on real widgets (CatShow).
struct CatShowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var inWidgets = CatShow.isOn
    @AppStorage("seenIntro") private var seenIntro = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    widgetSwitch
                    replayIntro
                    section("Cameos, one after another (glancing, napping)") {
                        TimelineView(.periodic(from: .now, by: CatShow.step / 2)) { context in
                            let index = Int(context.date.timeIntervalSinceReferenceDate / (CatShow.step / 2))
                            CardGrid {
                                ForEach([CardSize.small, .medium], id: \.self) { size in
                                    LiveCard(content: Self.card(CatShow.cameo(index), size), size: size)
                                        .cardSpan(size)
                                }
                            }
                        }
                    }
                    section("Every cameo") {
                        CardGrid {
                            ForEach(Array(WidgetContent.Cameo.Pose.allCases.enumerated()), id: \.element) { index, pose in
                                LiveCard(content: Self.card(.init(pose: pose), .small), size: .small, index: index)
                                    .overlay(alignment: .bottomLeading) { tag("\(pose)") }
                                    .arrive(index)
                            }
                        }
                    }
                    section("Poses") {
                        TimelineView(.periodic(from: .now, by: 0.2)) { context in
                            let ticks = Int(context.date.timeIntervalSinceReferenceDate / 0.2)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
                                ForEach(Array(Self.poses.enumerated()), id: \.offset) { index, item in
                                    // Each cat blinks on its own beat.
                                    let blinking = (ticks + index * 5) % 18 == 0
                                    VStack(spacing: 8) {
                                        CatArt(pose: item.pose, eyesClosed: blinking)
                                            .aspectRatio(CatArt.aspect(item.pose), contentMode: .fit)
                                            .frame(height: 110)
                                        tag(item.name)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 150)
                                    .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                                }
                            }
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.paper.ignoresSafeArea())
            .navigationTitle("Cat show")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                }
            }
        }
        .tint(Palette.ink)
        .foregroundStyle(Palette.ink)
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 640)
        #endif
    }

    private var widgetSwitch: some View {
        Toggle(isOn: $inWidgets) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Play in my widgets").font(.rounded(17, .black))
                Text("Every widget shows its tracker as a number and cycles through all cameos, glances and naps, \(Int(CatShow.step)) s each.")
                    .font(.rounded(13, .bold))
                    .opacity(0.6)
            }
        }
        .padding(16)
        .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onChange(of: inWidgets) { _, on in
            CatShow.isOn = on
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Shows the pull-the-cat intro again, over Home.
    private var replayIntro: some View {
        Button {
            seenIntro = false
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Replay intro").font(.rounded(17, .black))
                    Text("The long cat hanging from the top, the one you pull.")
                        .font(.rounded(13, .bold))
                        .opacity(0.6)
                }
                Spacer()
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 17, weight: .bold))
            }
            .padding(16)
            .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(SquishStyle(scale: 0.98))
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.rounded(20, .black))
            content()
        }
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.rounded(12, .heavy))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.white.opacity(0.7), in: Capsule())
            .padding(8)
    }

    private static let poses: [(name: String, pose: CatPose)] = [
        ("lying", .lying), ("walking", .walking), ("hanging", .hanging),
        ("peek", .peek), ("sitting", .sitting), ("tall", .tall),
    ]

    private static func card(_ cameo: WidgetContent.Cameo, _ size: CardSize) -> WidgetContent {
        var content = WidgetContent(state: PreviewStates.shared.named(name: "countdown-number", maxDots: size.maxDots))
        content.cameo = cameo
        return content
    }
}
