import Foundation

/// Cat show: real widgets cycle through every cameo, a few seconds each, so all of them
/// can be seen on the Home Screen or desktop. Switched on in the app; a flag file in the
/// shared App Group folder tells the widget.
enum CatShow {
    static let poses = WidgetContent.Cameo.Pose.allCases
    /// Seconds per pose. Widgets skip frames closer than about 1 s.
    static let step: TimeInterval = 3
    /// Rounds per timeline. Kept short: WidgetKit renders every frame up front.
    static let rounds = 5

    private static var flag: URL { Purrgets.folder.appendingPathComponent("cat-show") }

    static var isOn: Bool {
        get { FileManager.default.fileExists(atPath: flag.path) }
        set {
            if newValue {
                FileManager.default.createFile(atPath: flag.path, contents: Data())
            } else {
                try? FileManager.default.removeItem(at: flag)
            }
        }
    }

    /// The card's content with each pose in turn, starting [from]. Shown as a Number card,
    /// the only style cats visit.
    static func frames(of content: WidgetContent, from start: Date) -> [(Date, WidgetContent)] {
        (0..<poses.count * rounds).map { index in
            var copy = content
            copy.style = .number
            copy.cameo = cameo(index)
            return (start.addingTimeInterval(Double(index) * step), copy)
        }
    }

    /// Frame [index] of the show: every pose in turn, glancing left, ahead and right,
    /// and every fourth one napping.
    static func cameo(_ index: Int) -> WidgetContent.Cameo {
        .init(pose: poses[index % poses.count], look: Double(index % 3 - 1), eyesClosed: index % 4 == 3)
    }
}
