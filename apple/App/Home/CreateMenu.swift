import SwiftUI

enum CreateOption: String, CaseIterable, Identifiable {
    case countdown, timeSince, progress, calendar, library
    var id: Self { self }

    var title: String {
        switch self {
        case .countdown: "Countdown"
        case .timeSince: "Time since"
        case .progress: "Progress"
        case .calendar: "Import event"
        case .library: "Library"
        }
    }

    var subtitle: String {
        switch self {
        case .countdown: "Days until a date"
        case .timeSince: "Days since something began"
        case .progress: "Year, month, week or a range"
        case .calendar: "From your calendar"
        case .library: "Ready-made trackers"
        }
    }

    var icon: String {
        switch self {
        case .countdown: "hourglass"
        case .timeSince: "clock.arrow.circlepath"
        case .progress: "chart.bar.fill"
        case .calendar: "calendar"
        case .library: "square.grid.2x2.fill"
        }
    }

    var shortcut: KeyboardShortcut? {
        self == .countdown ? KeyboardShortcut("n") : nil
    }
}

/// The floating + button. It turns into × and the options spring up above it, one by one.
struct CreateMenu: View {
    static let sourceID = "create"

    @Binding var isOpen: Bool
    var zoom: Namespace.ID
    var pick: (CreateOption) -> Void

    /// One tap per option as it springs up.
    @State private var rowsIn = 0

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if isOpen {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(Palette.ink.opacity(0.12))
                    .ignoresSafeArea()
                    .onTapGesture { toggle() }
                    .transition(.opacity)
            }

            VStack(alignment: .trailing, spacing: 12) {
                if isOpen {
                    ForEach(Array(CreateOption.allCases.enumerated()), id: \.element) { index, option in
                        row(option)
                            .transition(
                                .asymmetric(
                                    insertion: .scale(scale: 0.4, anchor: .bottomTrailing)
                                        .combined(with: .opacity)
                                        .animation(Motion.bouncy.delay(Motion.stagger(CreateOption.allCases.count - 1 - index, step: 0.05))),
                                    removal: .scale(scale: 0.6, anchor: .bottomTrailing).combined(with: .opacity)
                                )
                            )
                    }
                }
                plusButton
            }
            .padding(.trailing, 20)
            .padding(.bottom, 12)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: isOpen)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: rowsIn)
        .task(id: isOpen) {
            guard isOpen else { return }
            // In step with the rows' staggered entrance, after the + button's own tap.
            try? await Task.sleep(for: .seconds(0.06))
            for _ in CreateOption.allCases {
                guard !Task.isCancelled else { return }
                rowsIn += 1
                try? await Task.sleep(for: .seconds(0.05))
            }
        }
    }

    private var plusButton: some View {
        Button(action: toggle) {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .bold))
                .rotationEffect(.degrees(isOpen ? 135 : 0))
                .foregroundStyle(Palette.paper)
                .frame(width: 64, height: 64)
                .background(Palette.ink, in: Circle())
                .shadow(color: Palette.ink.opacity(0.25), radius: 12, y: 6)
        }
        .buttonStyle(SquishStyle(scale: 0.9))
        .zoomSource(Self.sourceID, in: zoom)
        .accessibilityLabel(isOpen ? "Close" : "New tracker")
    }

    private func row(_ option: CreateOption) -> some View {
        Button { pick(option) } label: {
            HStack(spacing: 14) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(option.title).font(.rounded(17, .heavy))
                    Text(option.subtitle).font(.rounded(12, .bold)).opacity(0.55)
                }
                Image(systemName: option.icon)
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 48, height: 48)
                    .background(iconColor(option), in: Circle())
            }
            .foregroundStyle(Palette.ink)
            .padding(.leading, 18)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
            .background(Palette.paper, in: Capsule())
            .shadow(color: Palette.ink.opacity(0.12), radius: 10, y: 4)
        }
        .buttonStyle(SquishStyle())
    }

    private func iconColor(_ option: CreateOption) -> Color {
        switch option {
        case .countdown: Palette.tangerine
        case .timeSince: Palette.sand
        case .progress: Palette.marigold
        case .calendar, .library: Palette.ink.opacity(0.08)
        }
    }

    private func toggle() {
        withAnimation(Motion.bouncy) { isOpen.toggle() }
    }
}
