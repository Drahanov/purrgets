import Foundation
import SharedLogic

/// The Kotlin composition root for this process (app or widget).
/// Both point at the same App Group folder, so they read the same trackers.json.
enum Purrgets {
    /// The App Group folder shared by the app and the widget.
    /// Without the group (a signing or entitlement mistake) it falls back to this process's own
    /// folder, so the app and the widget stop seeing each other's trackers. That's loud in logs
    /// and stops a debug build.
    static let folder: URL = {
        let group = Bundle.main.object(forInfoDictionaryKey: "PurrgetsAppGroup") as? String ?? ""
        if let shared = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) {
            return shared
        }
        CatLog.app.fault("App Group \"\(group, privacy: .public)\" unavailable; app and widget won't share trackers")
        assertionFailure("App Group \"\(group)\" unavailable: check PurrgetsAppGroup and the entitlements")
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }()

    static let container: AppContainer = AppleContainerKt.appleContainer(appGroupDirectory: folder.path)
}

extension KotlinInstant {
    var date: Date { Date(timeIntervalSince1970: Double(toEpochMilliseconds()) / 1000) }
}
