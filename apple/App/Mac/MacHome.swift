#if os(macOS)
import SharedLogic
import SwiftUI

/// What the Mac sidebar shows: trackers (all or one kind), or a place to start a new one.
enum MacSection: Hashable, CaseIterable, Identifiable {
    case all, countdowns, timeSince, progress, library, calendar, settings
    var id: Self { self }

    static let trackerSections: [MacSection] = [.all, .countdowns, .timeSince, .progress]
    static let startSections: [MacSection] = [.library, .calendar]

    var title: String {
        switch self {
        case .all: "All trackers"
        case .countdowns: "Countdowns"
        case .timeSince: "Time since"
        case .progress: "Progress"
        case .library: "Library"
        case .calendar: "From Calendar"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .all: "square.grid.2x2"
        case .countdowns: "hourglass"
        case .timeSince: "clock.arrow.circlepath"
        case .progress: "chart.bar"
        case .library: "books.vertical"
        case .calendar: "calendar"
        case .settings: "gearshape"
        }
    }

    /// The kind this section lists, or nil for every kind.
    var kind: EditorDraft.Kind? {
        switch self {
        case .countdowns: .countdown
        case .timeSince: .timeSince
        case .progress: .progress
        default: nil
        }
    }

    /// What + makes while this section is showing.
    var createOption: CreateOption {
        switch kind {
        case .timeSince: .timeSince
        case .progress: .progress
        default: .countdown
        }
    }
}

/// The Mac window: a sidebar of tracker kinds and ways to start, and the cards in the middle.
/// HomeView still owns the editor, sheets and the intro; this is only the layout.
struct MacHome<Card: View, Empty: View>: View {
    @Binding var section: MacSection
    /// False until the store has loaded and while the intro covers the window.
    var showsContent: Bool
    @ViewBuilder var trackers: (Tracker, Int) -> Card
    @ViewBuilder var empty: () -> Empty
    var create: (CreateOption) -> Void
    var pickDraft: (EditorDraft) -> Void

    @Environment(TrackerStore.self) private var store
    @State private var columns = NavigationSplitViewVisibility.all
    @Namespace private var highlight

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            sidebar
                .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.paper)
                .navigationTitle(section.title)
                .navigationSubtitle(subtitle)
                .toolbarBackground(Palette.paper, for: .windowToolbar)
        }
        .tint(Palette.ink)
        #if DEBUG
        .onAppear {
            // Screenshots: `--section library` (or calendar, countdowns…) opens on that page.
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "--section"), arguments.indices.contains(index + 1),
               let match = MacSection.allCases.first(where: { "\($0)".lowercased() == arguments[index + 1].lowercased() }) {
                section = match
            }
        }
        #endif
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            NewTrackerButton(primary: section.createOption, create: create)
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 14)
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    SidebarHeader("Trackers")
                    ForEach(MacSection.trackerSections) { item in
                        SidebarRow(item: item, count: count(item), selected: section == item, highlight: highlight) {
                            select(item)
                        }
                    }
                    SidebarHeader("Start from").padding(.top, 14)
                    ForEach(MacSection.startSections) { item in
                        SidebarRow(item: item, count: nil, selected: section == item, highlight: highlight) {
                            select(item)
                        }
                    }
                }
                .padding(.horizontal, 10)
            }
            .scrollIndicators(.never)
            SidebarRow(item: .settings, count: nil, selected: section == .settings, highlight: highlight) {
                select(.settings)
            }
            .padding(.horizontal, 10)
            SidebarJoe()
        }
        .foregroundStyle(Palette.ink)
        .background(MacSidebarStyle.background.ignoresSafeArea())
    }

    private func select(_ item: MacSection) {
        withAnimation(Motion.snappy) { section = item }
    }

    private func count(_ item: MacSection) -> Int {
        store.trackers.filter { item.kind == nil || EditorDraft(tracker: $0).kind == item.kind }.count
    }

    // MARK: Detail

    @ViewBuilder private var detail: some View {
        if !showsContent {
            Color.clear
        } else {
            switch section {
            case .library: library
            case .settings:
                SettingsView()
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
            case .calendar:
                CalendarImportView(pick: pickDraft, embedded: true)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            default: trackerPage
            }
        }
    }

    @ViewBuilder private var trackerPage: some View {
        let shown = store.trackers.enumerated().filter { section.kind == nil || EditorDraft(tracker: $0.element).kind == section.kind }
        if store.trackers.isEmpty {
            ScrollView { empty().padding(.horizontal, 28).padding(.vertical, 20) }
                .scrollIndicators(.hidden)
        } else if shown.isEmpty {
            NothingHere(section: section) { create(section.createOption) }
        } else {
            ScrollView {
                // Redraw every minute, so numbers and fills stay live while the window is open.
                TimelineView(.everyMinute) { _ in
                    CardGrid(spacing: 18, minCell: 160) {
                        ForEach(shown, id: \.element.id) { index, tracker in
                            trackers(tracker, index)
                        }
                    }
                }
                .motion(Motion.bouncy, value: shown.map(\.element.id))
                .padding(.horizontal, 28)
                .padding(.top, 20)
                .padding(.bottom, 40)
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var library: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Ready-made trackers. Click one to tweak it and save.")
                    .font(.rounded(14, .bold))
                    .foregroundStyle(Palette.ink.opacity(0.55))
                CardGrid(spacing: 18, minCell: 160) {
                    ForEach(Array(store.templates.enumerated()), id: \.element.id) { index, template in
                        let draft = EditorDraft(draft: template.draft)
                        let small = store.content(for: draft, id: template.id, size: .small)
                        let size = small.homeSize
                        Button { pickDraft(draft) } label: {
                            LiveCard(
                                content: size == .small ? small : store.content(for: draft, id: template.id, size: size),
                                size: size, index: index
                            )
                        }
                        .buttonStyle(SquishStyle(scale: 0.96))
                        .hoverLift()
                        .cardSpan(size)
                        .arrive(index)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 40)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
    }

    private var subtitle: String {
        let date = Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide))
        switch section {
        case .library: return "\(store.templates.count) templates"
        case .calendar: return "Upcoming events"
        case .settings: return "Widgets, Joe and support"
        default:
            let count = count(section)
            return count == 0 ? date : "\(count) \(count == 1 ? "tracker" : "trackers") · \(date)"
        }
    }

}

/// A kind with no trackers yet: Joe sleeps, one button makes the first.
private struct NothingHere: View {
    var section: MacSection
    var create: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            SleepingCat(size: 110)
            Text("No \(section.title.lowercased()) yet")
                .font(.rounded(20, .black))
            Text(section.createOption.subtitle)
                .font(.rounded(14, .bold))
                .foregroundStyle(Palette.ink.opacity(0.55))
            Button("New \(section.createOption.title.lowercased())", systemImage: "plus", action: create)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 6)
        }
        .foregroundStyle(Palette.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .arrive()
    }
}

enum MacSidebarStyle {
    /// Warm sand, a shade deeper than the paper the cards sit on.
    static let background = Color(hex: 0xECE3D0)
}

extension MacSection {
    /// The tile colour behind the row icon, picked from the card colours.
    var tint: Color {
        switch self {
        case .all: Palette.ink
        case .countdowns: Palette.tangerine
        case .timeSince: Palette.marigold
        case .progress: Palette.sand
        case .library, .calendar, .settings: Palette.paper
        }
    }
}

/// The big ink button at the top of the sidebar. The left part makes what this page lists
/// (⌘N), the chevron opens every way to start.
private struct NewTrackerButton: View {
    var primary: CreateOption
    var create: (CreateOption) -> Void
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 2) {
            Button { create(primary) } label: {
                Label("New \(primary.title.lowercased())", systemImage: "plus")
                    .font(.rounded(13, .heavy))
                    .labelStyle(NewLabelStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 12)
                    .frame(height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SquishStyle(scale: 0.97))
            .keyboardShortcut("n")
            .help("New \(primary.title.lowercased()) (⌘N)")

            Rectangle().fill(Palette.paper.opacity(0.25)).frame(width: 1, height: 18)

            Menu {
                ForEach(CreateOption.allCases) { option in
                    Button { create(option) } label: { Label(option.title, systemImage: option.icon) }
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .heavy))
                    .frame(width: 32, height: 34)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More ways to start")
        }
        .foregroundStyle(Palette.paper)
        .background(Palette.ink, in: Capsule())
        .shadow(color: Palette.ink.opacity(hovered ? 0.3 : 0.15), radius: hovered ? 8 : 4, y: 3)
        .onHover { hovered = $0 }
        .motion(Motion.snappy, value: hovered)
    }
}

private struct NewLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon
                .font(.system(size: 11, weight: .black))
                .frame(width: 20, height: 20)
                .background(Palette.tangerine, in: Circle())
                .foregroundStyle(Palette.ink)
            configuration.title
        }
    }
}

private struct SidebarHeader: View {
    var title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title.uppercased())
            .font(.rounded(11, .heavy))
            .tracking(0.8)
            .opacity(0.4)
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
    }
}

/// A sidebar row: a coloured tile, the name, a count. The picked row is a lifted paper card
/// that glides between rows.
private struct SidebarRow: View {
    var item: MacSection
    var count: Int?
    var selected: Bool
    var highlight: Namespace.ID
    var action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                MacIconTile(icon: item.icon, tint: item.tint)
                Text(item.title)
                    .font(.rounded(13, selected ? .heavy : .bold))
                Spacer(minLength: 4)
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.rounded(12, .heavy))
                        .monospacedDigit()
                        .opacity(0.45)
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal, 7)
            .frame(height: 34)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Palette.paper)
                        .shadow(color: Palette.ink.opacity(0.1), radius: 3, y: 1)
                        .matchedGeometryEffect(id: "selection", in: highlight)
                } else if hovered {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.ink.opacity(0.05))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Joe blinks at the bottom of the sidebar. Click him for the cat show (debug builds).
private struct SidebarJoe: View {
    var body: some View {
        HStack(spacing: 10) {
            BlinkingCat(size: 30)
            VStack(alignment: .leading, spacing: 0) {
                Text("Mr Joe Long").font(.rounded(12, .heavy))
                Text("keeps an eye on your days").font(.rounded(11, .bold)).opacity(0.5)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
#endif
