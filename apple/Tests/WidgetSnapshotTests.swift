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
                } else if try Data(contentsOf: file) != png {
                    try png.write(to: file.deletingPathExtension().appendingPathExtension("failed.png"))
                    failures.append(file.lastPathComponent)
                }
            }
            try render(ContactSheet(cards: cards, size: size)).write(to: review.appendingPathComponent("\(size.rawValue).png"))
        }
        XCTAssertTrue(failures.isEmpty, "Changed: \(failures.joined(separator: ", "))")
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
