import Foundation

/// What a tracker card shows. Plain Swift, so views don't touch Kotlin types.
/// Built from the Kotlin `TrackerState` in WidgetContent+Kotlin.swift.
struct WidgetContent: Equatable {
    enum Style: Equatable {
        case number
        case ring
        case dots(Dots)
        case bar
        case longCat
        /// 0…1, how round the cat is.
    }

    struct Dots: Equatable {
        enum Shape: CaseIterable { case circle, square, paw }
        var total: Int
        var elapsed: Int
        var fillPast: Bool
        var shape: Shape

        func isFilled(_ index: Int) -> Bool { fillPast ? index < elapsed : index >= elapsed }
    }

    struct Cameo: Equatable {
        enum Pose: CaseIterable { case paws, tail, hang, walk, tall }
        var pose: Pose
        /// Where it looks on screen: -1 left, 0 ahead, 1 right.
        var look: Double = 0
    }

    var title: String
    var theme: CardTheme
    /// The big number or word: "75", "Today", "50".
    var value: String
    /// Next to the value: "days", "%".
    var unit: String
    /// Small line under it: "until 15 Dec", "1y 2m 5d".
    var caption: String
    /// 0…1 for rings, bars and the long cat.
    var fraction: Double
    var style: Style
    var cameo: Cameo?
    /// Set on the day of an exact-time countdown, for a live timer.
    var countdownTarget: Date?
    /// One line for the Lock Screen inline widget.
    var inline: String
}
