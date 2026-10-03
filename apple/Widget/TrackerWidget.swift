import SwiftUI
import WidgetKit

@main
struct PurrgetsWidgets: WidgetBundle {
    var body: some Widget {
        TrackerWidget()
    }
}

struct TrackerWidget: Widget {
    static let kind = "TrackerWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: SelectTrackerIntent.self, provider: TrackerProvider()) { entry in
            TrackerWidgetView(entry: entry)
        }
        .configurationDisplayName("Tracker")
        .description(Self.description)
        .supportedFamilies(Self.families)
        // Cards draw their own padding so cats can sit right on the edge.
        .contentMarginsDisabled()
    }

    /// The gallery shows a sample, so say up front that the user picks their own after adding.
    private static var description: LocalizedStringKey {
        #if os(macOS)
        "Shows one of your trackers. After adding it, right-click and Edit “Tracker” to pick which."
        #else
        "Shows one of your trackers. After adding it, hold it and tap Edit Widget to pick which."
        #endif
    }

    private static var families: [WidgetFamily] {
        #if os(iOS)
        [.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        #else
        [.systemSmall, .systemMedium]
        #endif
    }
}

struct TrackerWidgetView: View {
    var entry: TrackerEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch entry.content {
        case .tracker(let content):
            TrackerCard(content: content, size: family.cardSize)
                .environment(\.pokeTrackerID, entry.trackerID)
                .containerBackground(for: .widget) {
                    if family.cardSize.isAccessory { Color.clear } else { content.theme.background }
                }
                .widgetURL(entry.trackerID.map(AppLink.tracker))
                .overlay(alignment: .topTrailing) {
                    if entry.isExample && !family.cardSize.isAccessory { ExampleBadge() }
                }
        case .chooseTracker(let reason):
            ChooseTrackerCard(reason: reason, size: family.cardSize)
                .containerBackground(for: .widget) {
                    if family.cardSize.isAccessory { Color.clear } else { Palette.paper }
                }
        }
    }
}

/// Marks the gallery's sample card, so "Lisbon trip" reads as a demo rather than the user's widget.
private struct ExampleBadge: View {
    var body: some View {
        Text("Example")
            .font(.rounded(10, .heavy))
            .textCase(.uppercase)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(Palette.paper)
            .background(Palette.ink.opacity(0.8), in: Capsule())
            .padding(10)
    }
}
