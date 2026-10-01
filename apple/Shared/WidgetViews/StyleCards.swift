import SwiftUI

struct NumberCard: View {
    var content: WidgetContent
    var medium: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardTitle(text: content.title)
            Spacer(minLength: 0)
            ValueText(content: content, size: medium ? 64 : 52)
            CaptionText(content: content)
        }
        .frame(maxWidth: medium ? 220 : .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct RingCard: View {
    var content: WidgetContent
    var medium: Bool

    var body: some View {
        if medium {
            HStack(spacing: 18) {
                ring.frame(width: 128, height: 128)
                VStack(alignment: .leading, spacing: 0) {
                    CardTitle(text: content.title)
                    Spacer(minLength: 0)
                    CaptionText(content: content, size: 15)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                CardTitle(text: content.title)
                ring.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var ring: some View {
        ProgressRing(fraction: content.fraction, lineWidth: medium ? 13 : 11, track: inkTrack)
            .overlay {
                VStack(spacing: -2) {
                    Text(content.value).font(.rounded(medium ? 34 : 28, .black)).minimumScaleFactor(0.5).lineLimit(1)
                    if !content.unit.isEmpty {
                        Text(content.unit).font(.rounded(11, .heavy))
                    }
                }
                .padding(medium ? 22 : 18)
            }
    }
}

struct DotsCard: View {
    var content: WidgetContent
    var dots: WidgetContent.Dots
    var medium: Bool

    var body: some View {
        if medium {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    CardTitle(text: content.title)
                    Spacer(minLength: 0)
                    ValueText(content: content, size: 40)
                    CaptionText(content: content)
                }
                .frame(width: 112, alignment: .leading)
                DotGridView(dots: dots)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                CardTitle(text: content.title)
                DotGridView(dots: dots)
                HStack(alignment: .firstTextBaseline) {
                    Text(content.unit == "%" ? "\(content.value)%" : "\(content.value) \(content.unit)")
                        .font(.rounded(13, .black))
                    Spacer(minLength: 4)
                    CaptionText(content: content)
                }
            }
        }
    }
}

/// One dot per unit. Picks the column count that makes the dots as big as possible.
struct DotGridView: View {
    var dots: WidgetContent.Dots

    var body: some View {
        Canvas { context, size in
            let n = max(dots.total, 1)
            var best = (columns: 1, cell: 0.0)
            for columns in 1...n {
                let rows = (n + columns - 1) / columns
                let cell = min(size.width / Double(columns), size.height / Double(rows))
                if cell > best.cell { best = (columns, cell) }
            }
            let dot = best.cell * 0.74
            for index in 0..<dots.total {
                let x = Double(index % best.columns) * best.cell + (best.cell - dot) / 2
                let y = Double(index / best.columns) * best.cell + (best.cell - dot) / 2
                let rect = CGRect(x: x, y: y, width: dot, height: dot)
                let color = dots.isFilled(index) ? Palette.ink : Palette.ink.opacity(0.16)
                context.fill(path(for: dots.shape, in: rect), with: .color(color))
            }
        }
    }

    private func path(for shape: WidgetContent.Dots.Shape, in rect: CGRect) -> Path {
        switch shape {
        case .circle: return Path(ellipseIn: rect)
        case .square: return Path(roundedRect: rect, cornerRadius: rect.width * 0.22)
        case .paw: return PawPrint().path(in: rect)
        }
    }
}

/// A pad and four toes.
struct PawPrint: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        var path = Path(ellipseIn: CGRect(x: rect.minX + w * 0.22, y: rect.minY + w * 0.42, width: w * 0.56, height: w * 0.5))
        let toes: [(CGFloat, CGFloat)] = [(0.02, 0.3), (0.24, 0.04), (0.52, 0.04), (0.74, 0.3)]
        for (x, y) in toes {
            path.addEllipse(in: CGRect(x: rect.minX + w * x, y: rect.minY + w * y, width: w * 0.24, height: w * 0.3))
        }
        return path
    }
}

struct BarCard: View {
    var content: WidgetContent
    var medium: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardTitle(text: content.title)
            Spacer(minLength: 0)
            ValueText(content: content, size: medium ? 56 : 44)
            CaptionText(content: content)
                .padding(.bottom, 10)
            ProgressBar(fraction: content.fraction, height: medium ? 14 : 12, track: inkTrack)
        }
    }
}

struct LongCatCard: View {
    var content: WidgetContent
    var medium: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                CardTitle(text: content.title)
                Spacer(minLength: 4)
                if medium { CaptionText(content: content) }
            }
            ValueText(content: content, size: medium ? 40 : 34)
            if !medium { CaptionText(content: content) }
            Spacer(minLength: 0)
            LongCatView(fraction: content.fraction)
                .frame(height: medium ? 54 : 44)
        }
    }
}

struct FatCatCard: View {
    var content: WidgetContent
    var growth: Double
    var medium: Bool

    var body: some View {
        if medium {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    CardTitle(text: content.title)
                    Spacer(minLength: 0)
                    ValueText(content: content, size: 56)
                    CaptionText(content: content)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                FatCatView(growth: growth).frame(width: 150)
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                CardTitle(text: content.title)
                ValueText(content: content, size: 34)
                CaptionText(content: content)
                FatCatView(growth: growth)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

/// Lock Screen sizes. Drawn in .primary: the system tints them.
struct AccessoryCard: View {
    var content: WidgetContent
    var size: CardSize

    var body: some View {
        switch size {
        case .circular:
            ProgressRing(fraction: content.fraction, lineWidth: 6, track: .primary.opacity(0.25))
                .overlay {
                    VStack(spacing: -3) {
                        Text(content.value)
                            .font(.rounded(Int(content.value) == nil ? 12 : 20, .black))
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                        Text(content.unit == "%" ? "%" : (content.unit.isEmpty ? "" : "days"))
                            .font(.rounded(9, .bold))
                    }
                    .padding(10)
                }
        case .rectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(content.title).font(.rounded(13, .bold)).lineLimit(1)
                ValueText(content: content, size: 24)
                ProgressBar(fraction: content.fraction, height: 5, track: .primary.opacity(0.25))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            Text(content.inline).font(.rounded(13, .bold)).lineLimit(1)
        }
    }
}
