import SwiftUI

extension EnvironmentValues {
    /// Off in snapshots, so pictures don't change with the clock.
    @Entry var liveTimers = true
}

/// One tracker at one size. Used by the widget, the app's cards and the editor preview.
/// Draws no background: the widget uses containerBackground, previews use `TrackerCardPreview`.
struct TrackerCard: View {
    var content: WidgetContent
    var size: CardSize

    var body: some View {
        if size.isAccessory {
            AccessoryCard(content: content, size: size)
        } else {
            ZStack {
                padded(styled)
                // The spec: cats peek into Number cards.
                if let cameo = content.cameo, case .number = content.style {
                    CameoView(cameo: cameo)
                    textOverCat(cameo)
                        .allowsHitTesting(false)
                }
            }
            .foregroundStyle(Palette.ink)
        }
    }

    /// Keeps text readable where the cat covers it. Over the big head the text is cut out of the cat
    /// in the card colour; thin legs and tails would chop cut-out letters up, so there the text stays
    /// on top with a card-coloured outline and the cat passes behind it.
    @ViewBuilder private func textOverCat(_ cameo: WidgetContent.Cameo) -> some View {
        let background = content.theme.background
        if cameo.pose.textOverCat == .cutout {
            padded(styled)
                .foregroundStyle(background)
                .mask { CameoView(cameo: cameo).environment(\.pokeTrackerID, nil) }
        } else {
            padded(ZStack(alignment: .topLeading) {
                // Card-coloured copies around the text make the outline; over the card itself they don't show.
                ForEach(0..<8, id: \.self) { step in
                    let angle = Double(step) * .pi / 4
                    styled
                        .foregroundStyle(background)
                        .offset(x: 1.5 * cos(angle), y: 1.5 * sin(angle))
                }
                styled
            })
        }
    }

    private func padded(_ view: some View) -> some View {
        view
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private var styled: some View {
        let medium = size == .medium
        switch content.style {
        case .number: NumberCard(content: content, medium: medium)
        case .ring: RingCard(content: content, medium: medium)
        case .dots(let dots): DotsCard(content: content, dots: dots, medium: medium)
        case .bar: BarCard(content: content, medium: medium)
        case .longCat: LongCatCard(content: content, medium: medium)
        }
    }
}

/// A card as it looks on the Home Screen, for the app and snapshots.
struct TrackerCardPreview: View {
    var content: WidgetContent
    var size: CardSize

    var body: some View {
        let frame = size.previewSize
        if size.isAccessory {
            TrackerCard(content: content, size: size)
                .frame(width: frame.width, height: frame.height)
                .padding(8)
                .background(Color(white: 0.12))
                .environment(\.colorScheme, .dark)
        } else {
            TrackerCard(content: content, size: size)
                .frame(width: frame.width, height: frame.height)
                .background(content.theme.background)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .paperEdge(content.theme, cornerRadius: 22)
        }
    }
}

/// How text stays readable where a cameo covers it; see `TrackerCard.textOverCat`.
enum TextOverCat {
    case cutout, outline
}

extension WidgetContent.Cameo.Pose {
    var textOverCat: TextOverCat {
        switch self {
        case .paws: .cutout
        case .tail, .hang, .walk, .tall: .outline
        }
    }
}

extension View {
    /// Paper cards are the app's own background colour, so in the app they need an edge to stand out.
    func paperEdge(_ theme: CardTheme, cornerRadius: CGFloat) -> some View {
        overlay {
            if theme == .paper {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Palette.ink.opacity(0.14), lineWidth: 1.5)
            }
        }
    }
}

// MARK: - Building blocks

struct CardTitle: View {
    var text: String
    var body: some View {
        Text(text).font(.rounded(13, .heavy)).lineLimit(1)
    }
}

struct ValueText: View {
    var content: WidgetContent
    var size: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(content.value)
                .font(.rounded(size, .black))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                // Digits roll when the value changes: between widget entries and in the app.
                .contentTransition(.numericText(countsDown: true))
            if !content.unit.isEmpty {
                Text(content.unit)
                    .font(.rounded(max(11, size * 0.3), .heavy))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}

struct CaptionText: View {
    var content: WidgetContent
    var size: CGFloat = 12
    @Environment(\.liveTimers) private var liveTimers

    var body: some View {
        Group {
            if liveTimers, let target = content.countdownTarget, target > .now {
                Text(timerInterval: Date.now...target, countsDown: true)
            } else {
                Text(content.caption)
            }
        }
        .font(.rounded(size, .bold))
        .opacity(0.65)
        .lineLimit(1)
    }
}

struct ProgressRing: View {
    var fraction: Double
    var lineWidth: CGFloat
    var track: Color

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            // At 0% a round cap would still draw a dot.
            if fraction > 0 {
                Circle()
                    .trim(from: 0, to: min(fraction, 1))
                    .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .padding(lineWidth / 2)
    }
}

struct ProgressBar: View {
    var fraction: Double
    var height: CGFloat
    var track: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().frame(width: max(height, geo.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: height)
    }
}

let inkTrack = Palette.ink.opacity(0.15)
