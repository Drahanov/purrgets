import SwiftUI

/// A widget with no tracker yet. WidgetKit can't tell widgets apart, so instead of guessing
/// one for it, it says how to pick one (or, with no trackers at all, how to make one).
/// The cat hangs its paws over the top edge, waiting.
struct ChooseTrackerCard: View {
    enum Reason { case pick, noTrackers }

    var reason: Reason
    var size: CardSize

    var body: some View {
        if size.isAccessory {
            accessory
        } else {
            ZStack {
                Group {
                    if size == .medium { medium } else { small }
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                CameoView(cameo: .init(cat: .long, pose: .paws))
            }
            .foregroundStyle(Palette.ink)
        }
    }

    // MARK: Home Screen

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
            Spacer(minLength: 0)
            Text(title)
                .font(.rounded(24, .black))
                .lineSpacing(-4)
                .fixedSize(horizontal: false, vertical: true)
            Text(hint)
                .font(.rounded(12, .bold))
                .opacity(0.6)
                .padding(.top, 4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var medium: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                brand
                Spacer(minLength: 0)
                Text(title)
                    .font(.rounded(26, .black))
                    .lineSpacing(-4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.rounded(11, .black))
                            .frame(width: 20, height: 20)
                            .background(Palette.marigold, in: Circle())
                        Text(step)
                            .font(.rounded(12, .heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .frame(width: 150, alignment: .leading)
        }
    }

    private var brand: some View {
        HStack(spacing: 5) {
            PawPrint().frame(width: 12, height: 12)
            Text("Purrgets").font(.rounded(12, .heavy))
        }
        .opacity(0.5)
    }

    // MARK: Lock Screen

    @ViewBuilder private var accessory: some View {
        switch size {
        case .circular:
            ZStack {
                Circle().stroke(.primary.opacity(0.25), style: StrokeStyle(lineWidth: 5, dash: [3, 4]))
                VStack(spacing: 1) {
                    PawPrint().frame(width: 20, height: 20)
                    Text(reason == .pick ? "Pick" : "Add").font(.rounded(10, .heavy))
                }
            }
            .padding(3)
        case .rectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    PawPrint().frame(width: 11, height: 11)
                    Text("Purrgets").font(.rounded(12, .bold))
                }
                .opacity(0.7)
                Text(title.replacingOccurrences(of: "\n", with: " ")).font(.rounded(16, .black)).lineLimit(1)
                Text(lockHint).font(.rounded(12, .bold)).lineLimit(1).opacity(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            Text(reason == .pick ? "Purrgets · hold to pick a tracker" : "Purrgets · make a tracker first")
                .font(.rounded(13, .bold))
                .lineLimit(1)
        }
    }

    // MARK: Words

    private var title: String {
        reason == .pick ? "Pick a\ntracker" : "No trackers\nyet"
    }

    private var hint: String {
        guard reason == .pick else { return "Open Purrgets and make one." }
        #if os(macOS)
        return "Right-click, then Edit “Tracker”."
        #else
        return "Hold here, then Edit Widget."
        #endif
    }

    private var lockHint: String {
        reason == .pick ? "Hold, then Edit Widget" : "Open Purrgets to make one"
    }

    private var steps: [String] {
        guard reason == .pick else { return ["Open Purrgets", "Tap + to make one", "Come back here"] }
        #if os(macOS)
        return ["Right-click this widget", "Edit “Tracker”", "Pick a tracker"]
        #else
        return ["Hold this widget", "Tap Edit Widget", "Pick a tracker"]
        #endif
    }
}
