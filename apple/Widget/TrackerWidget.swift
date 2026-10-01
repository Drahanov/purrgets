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
        .description("A countdown, time since or progress tracker.")
        .supportedFamilies(Self.families)
        // Cards draw their own padding so cats can sit right on the edge.
        .contentMarginsDisabled()
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
                .containerBackground(for: .widget) {
                    if family.cardSize.isAccessory { Color.clear } else { content.theme.background }
                }
        case .chooseTracker(let reason):
            ChooseTrackerCard(reason: reason, size: family.cardSize)
                .containerBackground(for: .widget) {
                    if family.cardSize.isAccessory { Color.clear } else { Palette.paper }
                }
        }
    }
}
