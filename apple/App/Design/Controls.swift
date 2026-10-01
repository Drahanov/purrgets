import SwiftUI

/// A segmented control whose ink pill slides to the picked option.
struct PillPicker<Option: Hashable, Label: View>: View {
    var options: [Option]
    @Binding var selection: Option
    @ViewBuilder var label: (Option) -> Label
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button {
                    withAnimation(Motion.snappy) { selection = option }
                } label: {
                    label(option)
                        .font(.rounded(14, .heavy))
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(selected ? Palette.paper : Palette.ink)
                        .background {
                            if selected {
                                Capsule().fill(Palette.ink).matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Palette.ink.opacity(0.07), in: Capsule())
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// A rounded tag that turns ink when picked.
struct Chip<Label: View>: View {
    var selected: Bool
    var action: () -> Void
    @ViewBuilder var label: Label

    var body: some View {
        Button(action: action) {
            label
                .font(.rounded(14, .heavy))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .foregroundStyle(selected ? Palette.paper : Palette.ink)
                .background(selected ? Palette.ink : Palette.ink.opacity(0.07), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(SquishStyle())
        .motion(Motion.snappy, value: selected)
    }
}

/// The four card colours. The ring around the picked one glides between them.
struct ThemeSwatches: View {
    @Binding var theme: CardTheme
    @Namespace private var ring

    var body: some View {
        HStack(spacing: 14) {
            ForEach(CardTheme.allCases, id: \.self) { option in
                Button {
                    withAnimation(Motion.bouncy) { theme = option }
                } label: {
                    Circle()
                        .fill(option.background)
                        .overlay(Circle().stroke(Palette.ink.opacity(0.12), lineWidth: 1))
                        .frame(width: 36, height: 36)
                        .padding(5)
                        .overlay {
                            if option == theme {
                                Circle().stroke(Palette.ink, lineWidth: 2.5).matchedGeometryEffect(id: "ring", in: ring)
                            }
                        }
                        .scaleEffect(option == theme ? 1.06 : 1)
                }
                .buttonStyle(SquishStyle(scale: 0.88))
                .accessibilityLabel(option.name)
            }
        }
        .sensoryFeedback(.selection, trigger: theme)
    }
}

extension CardTheme {
    var name: String {
        switch self {
        case .tangerine: "Tangerine"
        case .marigold: "Marigold"
        case .sand: "Sand"
        case .paper: "Paper"
        }
    }
}

/// A titled block in the editor.
struct EditorSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.rounded(12, .heavy))
                .tracking(0.8)
                .foregroundStyle(Palette.ink.opacity(0.5))
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// The big ink action button.
struct InkButton: View {
    var title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.rounded(17, .heavy))
            .foregroundStyle(Palette.paper)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Palette.ink, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(SquishStyle())
    }
}
