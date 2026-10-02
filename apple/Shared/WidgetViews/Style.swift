import SwiftUI

/// Colours and fonts from docs/product/DESIGN.md.
enum Palette {
    static let ink = Color(hex: 0x161514)
    static let tangerine = Color(hex: 0xEE8B3A)
    static let marigold = Color(hex: 0xF2B441)
    static let sand = Color(hex: 0xDDD3B4)
    static let paper = Color(hex: 0xF6F1E7)
    static let nose = Color(hex: 0xF2A0A6)
    static let cream = Color(hex: 0xF6F1E7)
    /// Cat whiskers: outside the body, and drawn over black (concept/cats).
    static let whisker = Color(hex: 0x6B4A45)
    static let whiskerOnInk = Color(hex: 0xCFC8BC)
}

enum CardTheme: CaseIterable {
    case tangerine, marigold, sand, paper

    var background: Color {
        switch self {
        case .tangerine: Palette.tangerine
        case .marigold: Palette.marigold
        case .sand: Palette.sand
        case .paper: Palette.paper
        }
    }
}

extension Font {
    /// SF Pro Rounded. Black for numbers, Heavy for titles, Bold for labels.
    static func rounded(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Widget sizes we design for.
enum CardSize: String, CaseIterable {
    case small, medium, circular, rectangular, inline

    var isAccessory: Bool { self == .circular || self == .rectangular || self == .inline }

    /// Points on a 6.1" iPhone; used for previews and snapshots.
    var previewSize: CGSize {
        switch self {
        case .small: CGSize(width: 170, height: 170)
        case .medium: CGSize(width: 364, height: 170)
        case .circular: CGSize(width: 76, height: 76)
        case .rectangular: CGSize(width: 172, height: 76)
        case .inline: CGSize(width: 240, height: 22)
        }
    }

    /// Dot limits from the spec: about 100 on Small, 200 on Medium.
    var maxDots: Int32 { self == .medium ? 200 : 100 }
}
