import Foundation

#if os(iOS)
import UIKit
#endif

/// Where support, reviews and legal pages live. Empty or nil hides what needs it.
enum AppInfo {
    /// Bug reports and feedback go here. Empty leaves the To field for the user to fill.
    static let supportEmail = "supp.bld.tech@gmail.com"
    /// The App Store id, once the app has one. Turns on "Share" and the direct review page.
    static let appStoreID: String? = "6818740758"
    static let privacyURL = URL(string: "https://drahanov.github.io/purrgets/privacy.html")
    static let termsURL: URL? = nil

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }

    static var appStoreURL: URL? {
        appStoreID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)") }
    }

    /// Opens the App Store straight on the "Write a review" page.
    static var writeReviewURL: URL? {
        appStoreID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)?action=write-review") }
    }

    /// A draft email with [subject], and the device details under the line for bug reports.
    static func mail(subject: String, diagnostics trackers: Int? = nil) -> URL? {
        var body = "\n\n"
        if let trackers {
            body = "What happened?\n\n\nWhat did you expect?\n\n\n— Please keep the lines below, they help us find the bug —\n"
                + diagnostics(trackers: trackers)
        }
        var parts = URLComponents()
        parts.scheme = "mailto"
        parts.path = supportEmail
        parts.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body)]
        return parts.url
    }

    static func diagnostics(trackers: Int) -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        #if os(iOS)
        let system = "\(UIDevice.current.systemName) \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        #else
        let system = "macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        #endif
        return """
        Purrgets \(version) (\(build))
        \(system), \(deviceModel)
        Trackers: \(trackers)
        Language: \(Locale.current.identifier)
        """
    }

    /// The hardware name, e.g. "iPhone17,1" or "Mac15,6".
    private static var deviceModel: String {
        #if os(iOS)
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return simulated + " (Simulator)" }
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        #else
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: max(size, 1))
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
        #endif
    }
}
