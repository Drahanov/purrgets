import Foundation

/// Links into the app, e.g. from a widget tap: purrgets://tracker/<id>.
enum AppLink {
    static let scheme = "purrgets"

    static func tracker(_ id: String) -> URL {
        URL(string: "\(scheme)://tracker/\(id)")!
    }

    /// The tracker a link opens, if it's a tracker link.
    static func trackerID(_ url: URL) -> String? {
        guard url.scheme == scheme, url.host() == "tracker" else { return nil }
        let id = url.lastPathComponent
        return id.isEmpty || id == "/" ? nil : id
    }
}
