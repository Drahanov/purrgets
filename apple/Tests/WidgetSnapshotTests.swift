import SharedLogic
import SwiftUI
import XCTest

/// Renders every sample tracker at every size and compares it with the saved PNG in
/// __Snapshots__. A missing PNG is recorded. Set RECORD_SNAPSHOTS=1 to re-record all.
/// Also writes one contact sheet per size to build/snapshot-review for a quick look.
@MainActor
final class WidgetSnapshotTests: XCTestCase {
    private let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("__Snapshots__")
    private let review = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("../build/snapshot-review").standardized
    private let record = ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1"

    func testEveryStyleAtEverySize() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: review, withIntermediateDirectories: true)
        var failures: [String] = []

        for size in CardSize.allCases {
            let samples = PreviewStates.shared.all(maxDots: size.maxDots)
            var cards: [(String, WidgetContent)] = []
            for sample in samples {
                let content = WidgetContent(state: sample.state)
                cards.append((sample.name, content))
                let png = try render(TrackerCardPreview(content: content, size: size))
                let file = folder.appendingPathComponent("\(sample.name)-\(size.rawValue).png")
                if record || !FileManager.default.fileExists(atPath: file.path) {
                    try png.write(to: file)
                } else if !Self.looksSame(try Data(contentsOf: file), png) {
                    try png.write(to: file.deletingPathExtension().appendingPathExtension("failed.png"))
                    failures.append(file.lastPathComponent)
                }
            }
            try render(ContactSheet(cards: cards, size: size)).write(to: review.appendingPathComponent("\(size.rawValue).png"))
        }
        XCTAssertTrue(failures.isEmpty, "Changed: \(failures.joined(separator: ", "))")
    }

    func testChooseTrackerCardAtEverySize() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var failures: [String] = []
        for reason in [ChooseTrackerCard.Reason.pick, .noTrackers] {
            for size in CardSize.allCases {
                let png = try render(ChooseTrackerPreview(reason: reason, size: size))
                let file = folder.appendingPathComponent("choose-\(reason == .pick ? "pick" : "none")-\(size.rawValue).png")
                if record || !FileManager.default.fileExists(atPath: file.path) {
                    try png.write(to: file)
                } else if !Self.looksSame(try Data(contentsOf: file), png) {
                    try png.write(to: file.deletingPathExtension().appendingPathExtension("failed.png"))
                    failures.append(file.lastPathComponent)
                }
            }
        }
        XCTAssertTrue(failures.isEmpty, "Changed: \(failures.joined(separator: ", "))")
    }

    /// Same size and every channel within 2/255. Byte-exact PNGs differ by rounding noise between runs.
    private static func looksSame(_ a: Data, _ b: Data) -> Bool {
        guard let first = NSBitmapImageRep(data: a), let second = NSBitmapImageRep(data: b),
              first.pixelsWide == second.pixelsWide, first.pixelsHigh == second.pixelsHigh,
              first.bitsPerPixel == second.bitsPerPixel, first.bytesPerRow == second.bytesPerRow,
              let p = first.bitmapData, let q = second.bitmapData
        else { return false }
        let count = first.bytesPerRow * first.pixelsHigh
        for index in 0..<count where abs(Int(p[index]) - Int(q[index])) > 2 { return false }
        return true
    }

    private func render(_ view: some View) throws -> Data {
        let renderer = ImageRenderer(content: view.environment(\.liveTimers, false))
        renderer.scale = 2
        guard let image = renderer.cgImage else { throw CocoaError(.fileWriteUnknown) }
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        return png
    }
}

/// All samples at one size in a labelled grid.
private struct ContactSheet: View {
    var cards: [(String, WidgetContent)]
    var size: CardSize

    var body: some View {
        let columns = size == .medium ? 3 : (size.isAccessory ? 4 : 5)
        Grid(horizontalSpacing: 20, verticalSpacing: 20) {
            ForEach(Array(stride(from: 0, to: cards.count, by: columns)), id: \.self) { start in
                GridRow {
                    ForEach(start..<min(start + columns, cards.count), id: \.self) { index in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(cards[index].0).font(.system(size: 11, weight: .semibold, design: .monospaced))
                            TrackerCardPreview(content: cards[index].1, size: size)
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }
}

/// The empty widget as it looks on the Home or Lock Screen.
private struct ChooseTrackerPreview: View {
    var reason: ChooseTrackerCard.Reason
    var size: CardSize

    var body: some View {
        let frame = size.previewSize
        if size.isAccessory {
            ChooseTrackerCard(reason: reason, size: size)
                .frame(width: frame.width, height: frame.height)
                .padding(8)
                .background(Color(white: 0.12))
                .environment(\.colorScheme, .dark)
        } else {
            ChooseTrackerCard(reason: reason, size: size)
                .frame(width: frame.width, height: frame.height)
                .background(Palette.paper)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}
