import SwiftUI

/// Lays cards out like a Home Screen: square cards take one column, wide cards two.
/// A square card fills the first gap it fits in, so wide cards don't leave holes.
/// One ForEach of cards keeps their identity, so inserts and deletes animate in place.
struct CardGrid: Layout {
    var spacing: CGFloat = 14
    /// The narrowest a square card may get before the grid drops a column.
    var minCell: CGFloat = 150

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 364
        let frames = place(subviews, width: width)
        return CGSize(width: width, height: frames.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, frame) in zip(subviews, place(subviews, width: bounds.width)) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func place(_ subviews: Subviews, width: CGFloat) -> [CGRect] {
        let columns = max(2, Int((width + spacing) / (minCell + spacing)))
        // Wide enough for 4+ columns (the Mac): keep cards at widget size instead of stretching.
        let cell = min((width - spacing * CGFloat(columns - 1)) / CGFloat(columns), 190)
        let inset = (width - cell * CGFloat(columns) - spacing * CGFloat(columns - 1)) / 2
        var rows: [[Bool]] = []
        var frames: [CGRect] = []

        for subview in subviews {
            let span = min(subview[CardSpan.self], columns)
            var slot: (row: Int, column: Int)?
            search: for row in rows.indices {
                for column in 0...(columns - span) where (column..<column + span).allSatisfy({ !rows[row][$0] }) {
                    slot = (row, column)
                    break search
                }
            }
            if slot == nil {
                rows.append(Array(repeating: false, count: columns))
                slot = (rows.count - 1, 0)
            }
            let (row, column) = slot!
            for taken in column..<column + span { rows[row][taken] = true }
            frames.append(CGRect(
                x: inset + CGFloat(column) * (cell + spacing),
                y: CGFloat(row) * (cell + spacing),
                width: cell * CGFloat(span) + spacing * CGFloat(span - 1),
                height: cell
            ))
        }
        return frames
    }
}

/// How many grid columns a card takes.
struct CardSpan: LayoutValueKey {
    static let defaultValue = 1
}

extension View {
    func cardSpan(_ size: CardSize) -> some View {
        layoutValue(key: CardSpan.self, value: size == .medium ? 2 : 1)
    }
}
