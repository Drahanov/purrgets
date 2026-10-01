import SwiftUI

/// Ready-made trackers. Tap one to open it in the editor, prefilled.
struct LibraryView: View {
    var pick: (EditorDraft) -> Void
    @Environment(TrackerStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                CardGrid {
                    ForEach(Array(store.templates.enumerated()), id: \.element.id) { index, template in
                        let draft = EditorDraft(draft: template.draft)
                        let small = store.content(for: draft, id: template.id, size: .small)
                        let size = small.homeSize
                        Button { pick(draft) } label: {
                            LiveCard(
                                content: size == .small ? small : store.content(for: draft, id: template.id, size: size),
                                size: size, index: index
                            )
                        }
                        .buttonStyle(SquishStyle(scale: 0.96))
                        .cardSpan(size)
                        .arrive(index)
                    }
                }
                .padding(18)
            }
            .background(Palette.paper.ignoresSafeArea())
            .navigationTitle("Library")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                }
            }
        }
        .tint(Palette.ink)
        .frame(minWidth: Platform.isMac ? 560 : nil, minHeight: Platform.isMac ? 560 : nil)
    }
}
