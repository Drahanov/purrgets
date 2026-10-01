import SharedLogic
import SwiftUI

/// What the editor opens with. [sourceID] names the card or button it zooms out of.
struct EditorRequest: Identifiable {
    let id = UUID().uuidString
    var draft: EditorDraft
    var trackerID: String?
    var sourceID: String
}

enum HomeSheet: String, Identifiable {
    case library, calendar
    var id: Self { self }
}

/// A just-saved tracker the "Add to Home Screen" guide shows.
struct GuideRequest: Identifiable {
    let id: String
}

/// The grid of tracker cards. Each card is drawn like its widget, live.
struct HomeView: View {
    @Environment(TrackerStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hideWidgetGuide") private var hideGuide = false

    @State private var editor: EditorRequest?
    @State private var sheet: HomeSheet?
    @State private var guide: GuideRequest?
    /// Opened once the sheet or editor on screen has gone (SwiftUI shows one at a time).
    @State private var nextEditor: EditorRequest?
    @State private var nextGuide: GuideRequest?
    @State private var menuOpen = false
    @State private var deleting: Tracker?
    @Namespace private var zoom

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HomeHeader(count: store.trackers.count)
                    if store.isLoaded {
                        if store.trackers.isEmpty {
                            EmptyHome(templates: store.templates) { template in
                                open(EditorDraft(draft: template.draft), from: "template-\(template.id)")
                            }
                        } else {
                            grid
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 120)
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)

            if !Platform.isMac {
                CreateMenu(isOpen: $menuOpen, zoom: zoom, pick: create)
            }
        }
        .background(Palette.paper.ignoresSafeArea())
        .toolbar {
            if Platform.isMac {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ForEach(CreateOption.allCases) { option in
                            Button { create(option) } label: { Label(option.title, systemImage: option.icon) }
                                .keyboardShortcut(option.shortcut)
                        }
                    } label: {
                        Label("New tracker", systemImage: "plus")
                    }
                }
            }
        }
        .cover(item: $editor, onDismiss: showNextGuide) { request in
            EditorView(store: store, request: request) { saved in
                if saved, request.trackerID == nil, !hideGuide { nextGuide = GuideRequest(id: request.id) }
            }
            .zoomTransition(request.sourceID, in: zoom)
        }
        .sheet(item: $sheet, onDismiss: showNextEditor) { sheet in
            switch sheet {
            case .library: LibraryView(pick: pickFromSheet)
            case .calendar: CalendarImportView(pick: pickFromSheet)
            }
        }
        .sheet(item: $guide) { _ in
            AddWidgetGuide(content: store.trackers.last.map { store.content(for: $0, size: .small) }) { hideGuide = true }
        }
        .confirmationDialog(
            "Delete “\(deleting?.title ?? "")”?", isPresented: .init(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible, presenting: deleting
        ) { tracker in
            Button("Delete", role: .destructive) { Task { await store.delete(id: tracker.id) } }
        } message: { _ in
            Text("Its widgets will ask you to pick another tracker.")
        }
        .task {
            await store.load()
            await runLaunchArguments()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.load() } }
        }
    }

    // MARK: Grid

    private var grid: some View {
        // Redraw every minute, so numbers and fills stay live while the app is open.
        TimelineView(.everyMinute) { _ in
            CardGrid {
                ForEach(Array(store.trackers.enumerated()), id: \.element.id) { index, tracker in
                    card(tracker, index: index)
                }
            }
        }
        .motion(Motion.bouncy, value: store.trackers.map(\.id))
    }

    private func card(_ tracker: Tracker, index: Int) -> some View {
        let small = store.content(for: tracker, size: .small)
        let size = small.homeSize
        let content = size == .small ? small : store.content(for: tracker, size: size)
        return Button {
            open(EditorDraft(tracker: tracker), trackerID: tracker.id, from: tracker.id)
        } label: {
            LiveCard(content: content, size: size, index: index)
        }
        .buttonStyle(SquishStyle(scale: 0.96))
        .zoomSource(tracker.id, in: zoom)
        .contextMenu {
            Button { open(EditorDraft(tracker: tracker), trackerID: tracker.id, from: tracker.id) } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button { Task { await store.duplicate(tracker) } } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            Divider()
            Button(role: .destructive) { deleting = tracker } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .cardSpan(size)
        .arrive(index)
        .transition(.scale(scale: 0.6).combined(with: .opacity))
    }

    // MARK: Navigation

    private func create(_ option: CreateOption) {
        menuOpen = false
        switch option {
        case .countdown: open(EditorDraft(kind: .countdown), from: CreateMenu.sourceID)
        case .timeSince: open(EditorDraft(kind: .timeSince), from: CreateMenu.sourceID)
        case .progress: open(EditorDraft(kind: .progress), from: CreateMenu.sourceID)
        case .calendar: sheet = .calendar
        case .library: sheet = .library
        }
    }

    private func open(_ draft: EditorDraft, trackerID: String? = nil, from source: String) {
        editor = EditorRequest(draft: draft, trackerID: trackerID, sourceID: source)
    }

    private func pickFromSheet(_ draft: EditorDraft) {
        nextEditor = EditorRequest(draft: draft, trackerID: nil, sourceID: CreateMenu.sourceID)
        sheet = nil
    }

    private func showNextEditor() {
        editor = nextEditor
        nextEditor = nil
    }

    private func showNextGuide() {
        guide = nextGuide
        nextGuide = nil
    }

    /// For automated screenshots: `--add-samples` fills an empty store, `--edit-first` opens the editor.
    private func runLaunchArguments() async {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--add-samples"), store.trackers.isEmpty {
            for template in store.templates {
                await store.save(id: TrackerKt.randomTrackerId(), draft: EditorDraft(draft: template.draft))
            }
        }
        if arguments.contains("--edit-first"), let first = store.trackers.first {
            open(EditorDraft(tracker: first), trackerID: first.id, from: first.id)
        }
        if arguments.contains("--new-countdown") { create(.countdown) }
        if arguments.contains("--new-dots") {
            var draft = EditorDraft(kind: .timeSince)
            draft.title = "Days since"
            draft.look = .dots
            draft.day = Calendar.current.date(byAdding: .day, value: -40, to: .now)!
            open(draft, from: CreateMenu.sourceID)
        }
        if arguments.contains("--guide") { guide = GuideRequest(id: "debug") }
        #endif
    }
}

// MARK: - Header

private struct HomeHeader: View {
    var count: Int

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.rounded(14, .heavy))
                    .foregroundStyle(Palette.ink.opacity(0.5))
                Text("Purrgets")
                    .font(.rounded(40, .black))
                    .foregroundStyle(Palette.ink)
            }
            Spacer()
            BlinkingCat(size: 40)
                .padding(.bottom, 4)
        }
        .padding(.top, Platform.isMac ? 8 : 12)
    }
}

// MARK: - Empty state

/// First launch: a sleeping cat and the templates to start from.
private struct EmptyHome: View {
    var templates: [Template]
    var pick: (Template) -> Void
    @Environment(TrackerStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 10) {
                SleepingCat(size: 130)
                Text("Nothing to count yet")
                    .font(.rounded(22, .black))
                Text("Start with one of these, or tap + to make your own.")
                    .font(.rounded(15, .bold))
                    .foregroundStyle(Palette.ink.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .arrive()

            CardGrid {
                ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
                    let draft = EditorDraft(draft: template.draft)
                    let small = store.content(for: draft, id: template.id, size: .small)
                    let size = small.homeSize
                    Button { pick(template) } label: {
                        LiveCard(content: size == .small ? small : store.content(for: draft, id: template.id, size: size), size: size, index: index)
                    }
                    .buttonStyle(SquishStyle(scale: 0.96))
                    .cardSpan(size)
                    .arrive(index + 1)
                }
            }
        }
        .foregroundStyle(Palette.ink)
    }
}
