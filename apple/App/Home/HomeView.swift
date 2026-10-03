import SharedLogic
import SwiftUI
import WidgetKit

/// What the editor opens with. [sourceID] names the card or button it zooms out of.
struct EditorRequest: Identifiable {
    let id = UUID().uuidString
    var draft: EditorDraft
    var trackerID: String?
    var sourceID: String
}

enum HomeSheet: String, Identifiable {
    case library, calendar, cats, settings
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
    /// The pull-the-cat intro has been seen (or skipped). Existing users never get it.
    @AppStorage("seenIntro") private var seenIntro = false

    @State private var editor: EditorRequest?
    @State private var sheet: HomeSheet?
    @State private var guide: GuideRequest?
    /// Opened once the sheet or editor on screen has gone (SwiftUI shows one at a time).
    @State private var nextEditor: EditorRequest?
    @State private var nextGuide: GuideRequest?
    @State private var menuOpen = false
    @State private var deleting: Tracker?
    #if os(macOS)
    @State private var router = MacRouter.shared
    #endif
    @Namespace private var zoom

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            #if os(macOS)
            MacHome(
                section: $router.section,
                showsContent: store.isLoaded && !showsIntro,
                trackers: { card($0, index: $1) },
                empty: { emptyShelf },
                create: create,
                pickDraft: { open($0, from: CreateMenu.sourceID) }
            )
            #else
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HomeHeader(count: store.trackers.count) { sheet = .cats }
                    if store.isLoaded, !showsIntro {
                        if store.trackers.isEmpty {
                            emptyShelf
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

            if !showsIntro {
                CreateMenu(isOpen: $menuOpen, zoom: zoom, pick: create) {
                    menuOpen = false
                    sheet = .settings
                }
            }
            #endif

            if showsIntro {
                IntroFlow {
                    withAnimation(.easeOut(duration: 0.25)) { seenIntro = true }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .background(Palette.paper.ignoresSafeArea())
        .cover(item: $editor, onDismiss: showNextGuide) { request in
            editorScreen(request) { saved in
                if saved, request.trackerID == nil, !hideGuide { nextGuide = GuideRequest(id: request.id) }
            }
        }
        .sheet(item: $sheet, onDismiss: showNextEditor) { sheet in
            switch sheet {
            case .library: LibraryView(pick: pickFromSheet)
            case .calendar: CalendarImportView(pick: pickFromSheet)
            case .cats: CatShowView()
            case .settings: SettingsView()
            }
        }
        .sheet(item: $guide) { _ in
            AddWidgetGuide(cards: store.trackers.last.map { tracker in GuideCards { store.content(for: tracker, size: $0) } } ?? .sample) {
                hideGuide = true
            }
        }
        .confirmationDialog(
            "Delete “\(deleting?.title ?? "")”?", isPresented: .init(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible, presenting: deleting
        ) { tracker in
            Button("Delete", role: .destructive) { Task { await store.delete(id: tracker.id) } }
        } message: { tracker in
            Text(store.deleteNote(for: tracker.id))
        }
        .alert(
            store.failure ?? "", isPresented: .init(get: { store.failure != nil }, set: { if !$0 { store.failure = nil } })
        ) {
            Button("OK", role: .cancel) {}
        }
        .onChange(of: deleting?.id) { _, id in
            if id != nil { Task { await store.refreshWidgetCounts() } }
        }
        .task {
            await store.load()
            if !store.trackers.isEmpty { seenIntro = true }
            await runLaunchArguments()
        }
        .onOpenURL { url in
            Task { await openLink(url) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.load() } }
        }
    }

    // MARK: Grid

    private var emptyShelf: some View {
        EmptyShelf(templates: store.templates) { template in
            open(EditorDraft(draft: template.draft), from: "template-\(template.id)")
        }
    }

    /// The phone editor zooms out of its card; the Mac gets a sheet laid out for a pointer.
    @ViewBuilder private func editorScreen(_ request: EditorRequest, finish: @escaping (Bool) -> Void) -> some View {
        #if os(macOS)
        MacEditorView(store: store, request: request, finish: finish)
        #else
        EditorView(store: store, request: request, finish: finish)
            .zoomTransition(request.sourceID, in: zoom)
        #endif
    }

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
        .hoverLift()
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
        #if os(macOS)
        // The Mac shows these as pages in the sidebar, not sheets.
        case .calendar: router.section = .calendar
        case .library: router.section = .library
        #else
        case .calendar: sheet = .calendar
        case .library: sheet = .library
        #endif
        }
    }

    private func open(_ draft: EditorDraft, trackerID: String? = nil, from source: String) {
        editor = EditorRequest(draft: draft, trackerID: trackerID, sourceID: source)
    }

    /// A widget tap: open that tracker in the editor.
    private func openLink(_ url: URL) async {
        guard let id = AppLink.trackerID(url) else { return }
        await store.load()
        guard let tracker = store.tracker(id: id) else { return }
        sheet = nil
        guide = nil
        open(EditorDraft(tracker: tracker), trackerID: tracker.id, from: tracker.id)
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

    /// The cat intro covers Home until it's done: on first launch (people who already have
    /// trackers are marked as having seen it), or when replayed from the cat show.
    private var showsIntro: Bool { store.isLoaded && !seenIntro }

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
        if arguments.contains("--cats") { sheet = .cats }
        if arguments.contains("--settings") {
            #if os(macOS)
            router.section = .settings
            #else
            sheet = .settings
            #endif
        }
        if arguments.contains("--menu") { menuOpen = true }
        if arguments.contains("--intro") { seenIntro = false }
        if arguments.contains("--cat-show-off") { CatShow.isOn = false; WidgetCenter.shared.reloadAllTimelines() }
        if arguments.contains("--cat-show-on") { CatShow.isOn = true; WidgetCenter.shared.reloadAllTimelines() }
        if arguments.contains("--reload-widgets") { WidgetCenter.shared.reloadAllTimelines() }
        #endif
    }
}

// MARK: - Header

private struct HomeHeader: View {
    var count: Int
    /// Tapping the cat opens the cat show. Debug builds only.
    var openCats: () -> Void

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
                #if DEBUG
                .simultaneousGesture(TapGesture().onEnded(openCats))
                #endif
                .padding(.bottom, 4)
        }
        .padding(.top, Platform.isMac ? 8 : 12)
    }
}

