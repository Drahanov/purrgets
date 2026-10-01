import SwiftUI

/// The styles as real mini widgets of this very tracker. Tap one to switch the preview to it.
struct StylePicker: View {
    var model: EditorViewModel
    @Namespace private var outline

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 14) {
                ForEach(Array(model.draft.looks.enumerated()), id: \.element) { index, look in
                    thumbnail(look, index: index)
                        .scrollTransition(axis: .horizontal) { view, phase in
                            view.scaleEffect(phase.isIdentity ? 1 : 0.86).opacity(phase.isIdentity ? 1 : 0.55)
                        }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: model.draft.look)
    }

    private func thumbnail(_ look: EditorDraft.Look, index: Int) -> some View {
        let selected = model.draft.look == look
        return Button {
            withAnimation(Motion.bouncy) { model.setLook(look) }
        } label: {
            VStack(spacing: 8) {
                LiveCard(content: model.content(look: look), size: .small, index: index)
                    .frame(width: 170, height: 170)
                    .scaleEffect(0.5)
                    .frame(width: 85, height: 85)
                    .padding(4)
                    .overlay {
                        if selected {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(Palette.ink, lineWidth: 3)
                                .matchedGeometryEffect(id: "outline", in: outline)
                        }
                    }
                    .scaleEffect(selected ? 1.04 : 1)
                Text(look.name)
                    .font(.rounded(12, .heavy))
                    .foregroundStyle(Palette.ink.opacity(selected ? 1 : 0.55))
            }
        }
        .buttonStyle(SquishStyle(scale: 0.92))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

extension EditorDraft.Look {
    var name: String {
        switch self {
        case .number: "Number"
        case .ring: "Ring"
        case .dots: "Dots"
        case .bar: "Bar"
        case .longCat: "Long cat"
        case .fatCat: "Fat cat"
        }
    }
}

extension EditorDraft.Kind {
    var name: String {
        switch self {
        case .countdown: "Countdown"
        case .timeSince: "Time since"
        case .progress: "Progress"
        }
    }
}

extension EditorDraft.Period {
    var name: String {
        switch self {
        case .year: "Year"
        case .month: "Month"
        case .week: "Week"
        case .custom: "Custom"
        }
    }
}

extension EditorDraft.DotUnit {
    var name: String {
        switch self {
        case .auto: "Auto"
        case .day: "Days"
        case .week: "Weeks"
        case .month: "Months"
        }
    }
}
