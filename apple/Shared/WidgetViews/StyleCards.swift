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
/// Animatable: in the app the filled dots sweep in as a wave.
struct DotGridView: View, Animatable {
    var dots: WidgetContent.Dots
    /// Draw in the foreground style instead of ink: for Lock Screen widgets, which the system tints.
    var onForeground = false
    private var elapsed: Double

    init(dots: WidgetContent.Dots, onForeground: Bool = false) {
        self.dots = dots
        self.onForeground = onForeground
        elapsed = Double(dots.elapsed)
    }

    var animatableData: Double {
        get { elapsed }
        set { elapsed = newValue }
    }

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
                var layer = context
                if !isFilled(index) { layer.opacity = onForeground ? 0.3 : 0.16 }
                layer.fill(path(for: dots.shape, in: rect), with: onForeground ? .foreground : .color(Palette.ink))
            }
        }
    }

    private func isFilled(_ index: Int) -> Bool {
        let filled = Double(index) < elapsed.rounded()
        return dots.fillPast ? filled : !filled
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

/// Lock Screen sizes. Drawn in .primary: the system tints them.
/// Each follows the tracker's style, so a dot tracker shows dots on the Lock Screen too.
struct AccessoryCard: View {
    var content: WidgetContent
    var size: CardSize

    var body: some View {
        switch size {
        case .circular: circular
        case .rectangular: rectangular
        default:
            Text(content.inline).font(.rounded(13, .bold)).lineLimit(1)
        }
    }

    // MARK: Circular

    @ViewBuilder private var circular: some View {
        switch content.style {
        case .number:
            centre(valueSize: 24)
        case .dots(let dots):
            DotRing(dots: dots).overlay { centre(valueSize: 18) }
        case .ring, .bar, .longCat:
            ProgressRing(fraction: content.fraction, lineWidth: 6, track: .primary.opacity(0.25))
                .overlay { centre(valueSize: 20) }
        }
    }

    private func centre(valueSize: CGFloat) -> some View {
        VStack(spacing: -3) {
            Text(content.value)
                .font(.rounded(Int(content.value) == nil ? valueSize * 0.6 : valueSize, .black))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .contentTransition(.numericText(countsDown: true))
            if !content.unit.isEmpty {
                Text(content.unit == "%" ? "%" : "days").font(.rounded(9, .bold))
            }
        }
        .padding(10)
    }

    // MARK: Rectangular

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(content.title).font(.rounded(13, .bold)).lineLimit(1)
            switch content.style {
            case .number:
                ValueText(content: content, size: 28)
            case .ring:
                HStack(spacing: 8) {
                    ProgressRing(fraction: content.fraction, lineWidth: 5, track: .primary.opacity(0.25))
                        .frame(width: 34, height: 34)
                    ValueText(content: content, size: 24)
                }
            case .dots(let dots):
                ValueText(content: content, size: 20)
                DotGridView(dots: dots.squeezed(into: 24), onForeground: true)
                    .frame(height: 9)
            case .bar, .longCat:
                ValueText(content: content, size: 24)
                ProgressBar(fraction: content.fraction, height: 5, track: .primary.opacity(0.25))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Dots around a circle, filled like the tracker's dot grid: for the circular Lock Screen widget.
private struct DotRing: View {
    var dots: WidgetContent.Dots

    var body: some View {
        Canvas { context, size in
            let ring = dots.squeezed(into: 16)
            let radius: Double = min(size.width, size.height) / 2 - 4
            let midX: Double = size.width / 2
            let midY: Double = size.height / 2
            for index in 0..<ring.total {
                let angle: Double = Double(index) / Double(ring.total) * 2 * Double.pi - Double.pi / 2
                let x: Double = midX + radius * cos(angle)
                let y: Double = midY + radius * sin(angle)
                var layer = context
                if !ring.isFilled(index) { layer.opacity = 0.3 }
                layer.fill(Path(ellipseIn: CGRect(x: x - 2.6, y: y - 2.6, width: 5.2, height: 5.2)), with: .foreground)
            }
        }
    }
}

extension WidgetContent.Dots {
    /// The same share filled, with [count] dots: Lock Screen widgets have room for only a few.
    func squeezed(into count: Int) -> Self {
        let share = total == 0 ? 0 : Double(elapsed) / Double(total)
        return Self(total: count, elapsed: Int((share * Double(count)).rounded()), fillPast: fillPast, shape: shape)
    }
}
