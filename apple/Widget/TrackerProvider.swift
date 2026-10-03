import SharedLogic
import WidgetKit

struct TrackerEntry: TimelineEntry {
    enum Content {
        case tracker(WidgetContent)
        /// No tracker picked yet, or it was deleted.
        case chooseTracker(ChooseTrackerCard.Reason)
    }

    let date: Date
    let content: Content
    /// The tracker shown, for taps: the cat pokes it, the rest of the card opens it in the app.
    var trackerID: String?
    /// The gallery's made-up sample, badged so nobody mistakes it for their own tracker.
    var isExample = false

    var cameoPose: WidgetContent.Cameo.Pose? {
        if case .tracker(let content) = content { content.cameo?.pose } else { nil }
    }

    /// One line for the logs: time, pose, gaze.
    var summary: String {
        let time = date.formatted(date: .omitted, time: .standard)
        guard case .tracker(let content) = content, let cameo = content.cameo else { return "  \(time) no cat" }
        return "  \(time) \(cameo.pose) look=\(cameo.look)"
    }
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
        // No fallback tracker: widgets can't be told apart, so every unpicked widget would show
        // the same one and change along with it. They ask the user to pick instead.
        guard let id = configuration.tracker?.id,
              let timeline = try? await Purrgets.container.buildWidgetTimeline.invoke(
                  id: id, maxDots: context.family.cardSize.maxDots,
                  // Lock Screen sizes never draw a cat, so they skip the 5-minute cat frames.
                  cameos: !context.family.cardSize.isAccessory
              )
        else {
            let hasTrackers = !((try? await Purrgets.container.listTrackers.invoke()) ?? []).isEmpty
            CatLog.widget.info("timeline \(configuration.tracker?.id ?? "none", privacy: .public) family=\(String(describing: context.family), privacy: .public): no tracker, asks to pick (hasTrackers=\(hasTrackers))")
            // The app reloads all widgets after every save, so this updates once a tracker exists.
            return Timeline(entries: [TrackerEntry(date: .now, content: .chooseTracker(hasTrackers ? .pick : .noTrackers))], policy: .never)
        }
        var entries = timeline.frames.map { state in
            TrackerEntry(date: state.at.date, content: .tracker(WidgetContent(state: state)), trackerID: id)
        }
        if CatShow.isOn, case .tracker(let content) = entries.first?.content {
            let show = CatShow.frames(of: content, from: .now).map { TrackerEntry(date: $0.0, content: .tracker($0.1), trackerID: id) }
            CatLog.widget.info("timeline \(id, privacy: .public) family=\(String(describing: context.family), privacy: .public): CAT SHOW \(show.count) frames, 3 s apart")
            return Timeline(entries: show, policy: .atEnd)
        }
        // Just tapped: the reaction replaces the first frame, then the plan carries on.
        if let poke = CatPoke.fresh(id), case .tracker(let content) = entries.first?.content, let cameo = content.cameo {
            let reaction = CatPoke.reaction(to: cameo, count: poke.count, from: .now).map { date, cameo in
                var copy = content
                copy.cameo = cameo
                return TrackerEntry(date: date, content: .tracker(copy), trackerID: id)
            }
            entries = reaction + entries.dropFirst().filter { $0.date > reaction.last!.date }
            CatLog.widget.info("timeline \(id, privacy: .public): POKE #\(poke.count) \(String(describing: cameo.pose), privacy: .public) -> \(String(describing: reaction.last!.cameoPose), privacy: .public)")
        }
        CatLog.widget.info("timeline \(id, privacy: .public) family=\(String(describing: context.family), privacy: .public): \(entries.count) frames, reload \(timeline.reloadAt.date.formatted(date: .omitted, time: .standard), privacy: .public)\n\(entries.prefix(6).map(\.summary).joined(separator: "\n"), privacy: .public)")
        return Timeline(entries: entries, policy: .after(timeline.reloadAt.date))
    }

    /// The widget gallery shows a sample before the user picks anything.
    private func sample(for family: WidgetFamily) -> TrackerEntry {
        let state = PreviewStates.shared.named(name: "countdown-number", maxDots: family.cardSize.maxDots)
        return TrackerEntry(date: .now, content: .tracker(WidgetContent(state: state)), isExample: true)
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
