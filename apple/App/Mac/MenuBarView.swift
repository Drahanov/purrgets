#if os(macOS)
import AppKit
import SwiftUI

/// The menu bar item: every tracker at a glance, live.
struct MenuBarView: View {
    @Environment(TrackerStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Purrgets").font(.rounded(15, .black))
                Spacer()
                BlinkingCat(size: 22)
            }
            .padding(.horizontal, 6)

            if store.trackers.isEmpty {
                Text("No trackers yet").font(.rounded(13, .bold)).opacity(0.55)
                    .padding(6)
            } else {
                TimelineView(.everyMinute) { _ in
                    VStack(spacing: 4) {
                        ForEach(Array(store.trackers.enumerated()), id: \.element.id) { index, tracker in
                            row(store.content(for: tracker, size: .small))
                                .arrive(index)
                        }
                    }
                }
            }

            Divider().padding(.vertical, 4)
            Button("Open Purrgets") {
                openWindow(id: Platform.mainWindow)
                NSApp.activate()
            }
            .keyboardShortcut("o")
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        .buttonStyle(MenuRowStyle())
        .foregroundStyle(Palette.ink)
        .padding(10)
        .frame(width: 290)
        .background(Palette.paper)
        .task { await store.load() }
    }

    private func row(_ content: WidgetContent) -> some View {
        HStack(spacing: 10) {
            ProgressRing(fraction: content.fraction, lineWidth: 3.5, track: Palette.ink.opacity(0.15))
                .frame(width: 22, height: 22)
                .padding(5)
                .background(content.theme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .paperEdge(content.theme, cornerRadius: 8)
            Text(content.title).font(.rounded(14, .heavy)).lineLimit(1)
            Spacer(minLength: 8)
            Text(content.unit == "%" ? "\(content.value)%" : "\(content.value) \(content.unit)")
                .font(.rounded(14, .black))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(6)
    }
}

private struct MenuRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rounded(13, .heavy))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Palette.ink.opacity(configuration.isPressed ? 0.1 : 0), in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
    }
}
#endif
