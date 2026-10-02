import Foundation
import SharedLogic

/// The Kotlin composition root for this process (app or widget).
/// Both point at the same App Group folder, so they read the same trackers.json.
enum Purrgets {
    /// The App Group folder shared by the app and the widget.
    static let folder: URL = {
        let group = Bundle.main.object(forInfoDictionaryKey: "PurrgetsAppGroup") as? String ?? ""
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }()

    static let container: AppContainer = AppleContainerKt.appleContainer(appGroupDirectory: folder.path)
}

extension KotlinInstant {
    var date: Date { Date(timeIntervalSince1970: Double(toEpochMilliseconds()) / 1000) }
}
