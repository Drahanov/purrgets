import Foundation
import SharedLogic

/// A real Kotlin container on a throwaway folder, with a fixed clock and time zone,
/// so tests never touch the App Group and never depend on today's date.
@MainActor
enum TestEnvironment {
    /// 1 Oct 2026, 12:00 in Europe/Kyiv.
    static let now = Date(timeIntervalSince1970: 1_790_845_200)

    static func makeStore(reloads: @escaping () -> Void = {}) -> TrackerStore {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("purrgets-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let container = AppContainer(storageDirectory: folder.path, calendar: nil, clock: FixedClock(date: now), zones: FixedZone())
        return TrackerStore(container: container, reloadWidgets: reloads)
    }
}

final class FixedClock: KotlinClock {
    let date: Date
    init(date: Date) { self.date = date }
    func now() -> KotlinInstant { .from(date) }
}

final class FixedZone: TimeZoneProvider {
    func current() -> KotlinTimeZone { KotlinTimeZone.companion.of(zoneId: "Europe/Kyiv") }
}
