import SharedLogic
import WidgetKit

struct TrackerEntry: TimelineEntry {
    enum Content {
        case tracker(WidgetContent)
        /// No tracker picked yet, or it was deleted.
        case chooseTracker
    }

    let date: Date
    let content: Content
}

/// Asks Kotlin for the frames (BuildWidgetTimeline) and hands them to WidgetKit.
struct TrackerProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> TrackerEntry {
        sample(for: context.family)
    }

    /// The widget gallery: the user's own newest tracker, or a sample if they have none yet.
    func snapshot(for configuration: SelectTrackerIntent, in context: Context) async -> TrackerEntry {
        if let entry = await timeline(for: configuration, in: context).entries.first, case .tracker = entry.content {
            return entry
        }
        return sample(for: context.family)
    }

    func timeline(for configuration: SelectTrackerIntent, in context: Context) async -> Timeline<TrackerEntry> {
        var picked = configuration.tracker
        if picked == nil { picked = await TrackerQuery().defaultResult() }
        guard let id = picked?.id,
              let timeline = try? await Purrgets.container.buildWidgetTimeline.invoke(id: id, maxDots: context.family.cardSize.maxDots)
        else {
            return Timeline(entries: [TrackerEntry(date: .now, content: .chooseTracker)], policy: .never)
        }
        let entries = timeline.frames.map { state in
            TrackerEntry(date: state.at.date, content: .tracker(WidgetContent(state: state)))
        }
        return Timeline(entries: entries, policy: .after(timeline.reloadAt.date))
    }

    /// The widget gallery shows a sample before the user picks anything.
    private func sample(for family: WidgetFamily) -> TrackerEntry {
        let state = PreviewStates.shared.named(name: "countdown-number", maxDots: family.cardSize.maxDots)
        return TrackerEntry(date: .now, content: .tracker(WidgetContent(state: state)))
    }
}

extension WidgetFamily {
    var cardSize: CardSize {
        switch self {
        case .systemMedium, .systemLarge, .systemExtraLarge: .medium
        #if os(iOS)
        case .accessoryCircular: .circular
        case .accessoryRectangular: .rectangular
        case .accessoryInline: .inline
        #endif
        default: .small
        }
    }
}
