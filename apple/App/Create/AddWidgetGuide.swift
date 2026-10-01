import SwiftUI

/// After the first save: apps can't add widgets themselves, so show how.
/// A tiny jiggling home screen where the new card drops into place, then the steps.
struct AddWidgetGuide: View {
    var content: WidgetContent?
    var hideForever: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 22) {
            MiniHomeScreen(content: content)
                .padding(.top, 28)
            Text(Platform.isMac ? "Put it on your desktop" : "Put it on your Home Screen")
                .font(.rounded(24, .black))
                .multilineTextAlignment(.center)
                .arrive(1)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.rounded(14, .black))
                            .frame(width: 28, height: 28)
                            .background(Palette.marigold, in: Circle())
                        Text(step)
                            .font(.rounded(15, .bold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .arrive(index + 2)
                }
            }
            .frame(maxWidth: 420, alignment: .leading)
            Spacer(minLength: 0)
            VStack(spacing: 6) {
                InkButton(title: "Got it") { dismiss() }
                Button("Don't show this again") {
                    hideForever()
                    dismiss()
                }
                .font(.rounded(14, .heavy))
                .foregroundStyle(Palette.ink.opacity(0.55))
                .padding(.vertical, 8)
            }
            .frame(maxWidth: 420)
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.paper.ignoresSafeArea())
        .presentationDetents([.large])
        .frame(minWidth: Platform.isMac ? 480 : nil, minHeight: Platform.isMac ? 640 : nil)
    }

    private var steps: [String] {
        if Platform.isMac {
            [
                "Right-click the desktop and choose Edit Widgets.",
                "Search for Purrgets and drag a size onto the desktop.",
                "Right-click the widget, choose Edit “Tracker” and pick your tracker.",
            ]
        } else {
            [
                "Touch and hold the Home Screen until the apps jiggle.",
                "Tap Edit, then Add Widget, and find Purrgets.",
                "Pick a size and tap Add Widget.",
                "Hold the widget, tap Edit Widget and choose your tracker.",
            ]
        }
    }
}

/// App icons jiggling, and the user's card dropping in with a bounce.
private struct MiniHomeScreen: View {
    var content: WidgetContent?
    @State private var dropped = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Group {
                if let content {
                    LiveCard(content: content, size: .small, cornerRadius: 22)
                        .frame(width: 170, height: 170)
                        .scaleEffect(0.82)
                        .frame(width: 140, height: 140)
                } else {
                    RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.tangerine)
                        .frame(width: 140, height: 140)
                }
            }
            .shadow(color: Palette.ink.opacity(0.2), radius: dropped ? 8 : 22, y: dropped ? 4 : 16)
            .scaleEffect(dropped ? 1 : 1.25)
            .offset(y: dropped ? 0 : -40)
            .opacity(dropped ? 1 : 0)
            .jiggle(seed: 0)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 14), count: 2), spacing: 14) {
                ForEach(0..<8, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(index.isMultiple(of: 3) ? Palette.sand : Palette.ink.opacity(0.12))
                        .frame(width: 28, height: 28)
                        .jiggle(seed: index + 1)
                }
            }
        }
        .padding(20)
        .background(Palette.marigold.opacity(0.35), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .onAppear {
            withAnimation(Motion.bouncy.delay(0.35)) { dropped = true }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: dropped)
        .accessibilityHidden(true)
    }
}

private extension View {
    /// The edit-mode wobble.
    func jiggle(seed: Int) -> some View {
        phaseAnimator([-1.0, 1.0]) { view, phase in
            view.rotationEffect(.degrees(phase * (seed.isMultiple(of: 2) ? 1.6 : -1.6)))
        } animation: { _ in
            .easeInOut(duration: 0.13 + Double(seed % 3) * 0.015)
        }
    }
}
