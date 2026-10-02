import AppIntents
import SwiftUI

extension EnvironmentValues {
    /// Set by the widget: taps on the cat poke this tracker's cat.
    @Entry var pokeTrackerID: String?
}

/// A tap on a widget's cat. WidgetKit reloads the widget after it runs (without using up its
/// budget), and the timeline then starts with CatPoke.reaction.
struct PokeCatIntent: AppIntent {
    static let title: LocalizedStringResource = "Poke the cat"
    static let isDiscoverable = false

    @Parameter(title: "Tracker") var trackerID: String

    init() {}

    init(trackerID: String) {
        self.trackerID = trackerID
    }

    func perform() async throws -> some IntentResult {
        CatPoke.record(trackerID)
        CatLog.widget.info("poke \(trackerID, privacy: .public)")
        return .result()
    }
}

/// Remembers the last tap per tracker in the App Group folder and plans the cat's reaction.
enum CatPoke {
    struct Poke: Codable {
        var at: Date
        /// Taps so far; picks the pose the cat ends in, so each tap ends somewhere new.
        var count: Int
    }

    /// How long after a tap the reload still plays the reaction.
    static let window: TimeInterval = 10
    /// Seconds between moves. Widgets skip frames closer than about 1 s.
    static let beat: TimeInterval = 1

    static func record(_ trackerID: String) {
        let count = (last(trackerID)?.count ?? 0) + 1
        try? JSONEncoder().encode(Poke(at: .now, count: count)).write(to: file(trackerID))
    }

    /// The tap still waiting for its reaction, if any.
    static func fresh(_ trackerID: String, now: Date = .now) -> Poke? {
        guard let poke = last(trackerID), now.timeIntervalSince(poke.at) < window else { return nil }
        return poke
    }

    /// Wakes up, glances left, right, left a beat apart, then moves to a new pose.
    static func reaction(to cameo: WidgetContent.Cameo, count: Int, from start: Date) -> [(Date, WidgetContent.Cameo)] {
        let poses = WidgetContent.Cameo.Pose.allCases
        let current = poses.firstIndex(of: cameo.pose) ?? 0
        // Any pose but the current one.
        let next = poses[(current + 1 + count % (poses.count - 1)) % poses.count]
        let glances: [WidgetContent.Cameo] = [-1, 1, -1].map { .init(pose: cameo.pose, look: $0) }
        let frames = glances + [.init(pose: next)]
        return frames.enumerated().map { index, frame in (start.addingTimeInterval(Double(index) * beat), frame) }
    }

    private static func last(_ trackerID: String) -> Poke? {
        guard let data = try? Data(contentsOf: file(trackerID)) else { return nil }
        return try? JSONDecoder().decode(Poke.self, from: data)
    }

    private static func file(_ trackerID: String) -> URL {
        Purrgets.folder.appendingPathComponent("poke-\(trackerID).json")
    }
}
