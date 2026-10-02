import SwiftUI

/// One editor for every way in: blank, template, calendar event or an existing tracker.
/// The live preview sits on top and shrinks as the form scrolls up into its space
/// (side by side when there's room, like on the Mac).
struct EditorView: View {
    @State private var model: EditorViewModel
    /// Called with true when the tracker was saved.
    private let finish: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var wide = false
    @State private var saveSucceeded = 0
    /// How far the form has scrolled, in points.
    @State private var scrolled: CGFloat = 0
    /// Shakes the title only once it's back on screen.
    @State private var titleShakes = 0
    @FocusState private var titleFocused: Bool

    init(store: TrackerStore, request: EditorRequest, finish: @escaping (Bool) -> Void) {
        _model = State(initialValue: EditorViewModel(store: store, draft: request.draft, trackerID: request.trackerID))
        self.finish = finish
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scroller in
                Group {
                    if wide {
                        HStack(spacing: 0) {
                            PreviewStage(model: model)
                                .frame(width: 420)
                                .frame(maxHeight: .infinity)
                            ScrollView { form }
                        }
                    } else {
                        narrow
                    }
                }
                // A failed save scrolls to what needs fixing, then points at it.
                .onChange(of: model.shakes) { reveal(using: scroller) }
            }
            .background(Palette.paper.ignoresSafeArea())
            .onGeometryChange(for: Bool.self, of: { $0.size.width > 720 }) { wide = $0 }
            .safeAreaInset(edge: .bottom) { saveBar }
            .navigationTitle(model.isNew ? "New \(model.draft.kind.name.lowercased())" : "Edit")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { close(saved: false) } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                }
            }
            .confirmationDialog("Delete “\(model.draft.title)”?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    Task {
                        await model.delete()
                        close(saved: false)
                    }
                }
            } message: {
                Text(model.deleteNote)
            }
            .onChange(of: confirmDelete) { _, open in
                if open { Task { await model.refreshWidgetCounts() } }
            }
        }
        .tint(Palette.ink)
        .sensoryFeedback(.error, trigger: model.shakes)
        .sensoryFeedback(.success, trigger: saveSucceeded)
    }

    /// The preview floats over the top of the form. The form starts below it with a spacer of
    /// the preview's full height; as it scrolls, the preview shrinks at the same pace, so the
    /// form moves up into the freed space. Past full collapse, the form slides under the
    /// preview and fades. The form's layout never depends on the scroll, so nothing jitters.
    private var narrow: some View {
        let shrink = min(scrolled, PreviewStage.maxShrink)
        return ScrollView {
            VStack(spacing: 0) {
                Color.clear.frame(height: PreviewStage.fullHeight).id("top")
                form.padding(.top, 6)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y + $0.contentInsets.top }) { _, offset in
            scrolled = max(offset, 0)
        }
        .overlay(alignment: .top) {
            PreviewStage(model: model, collapse: shrink / PreviewStage.maxShrink)
                .frame(height: PreviewStage.fullHeight - shrink, alignment: .top)
                .background(alignment: .bottom) {
                    // The fade only matters once the form slides under the shrunk preview;
                    // before that it would cover the name field.
                    fadingBackdrop(fade: Double(min(max((scrolled - PreviewStage.maxShrink) / 24, 0), 1)))
                }
        }
    }

    private func reveal(using scroller: ScrollViewProxy) {
        // The very top shows the title right under the full-size preview.
        let target = model.titleMissing ? (wide ? "title" : "top") : (model.rangeInvalid ? "range" : nil)
        guard let target else { return }
        withAnimation(Motion.gentle) { scroller.scrollTo(target, anchor: target == "range" ? .center : .top) }
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            if model.titleMissing {
                titleShakes += 1
                titleFocused = true
            }
        }
    }

    /// Paper behind the preview that melts into the form below it.
    private func fadingBackdrop(fade: Double) -> some View {
        Palette.paper
            .ignoresSafeArea(edges: .top)
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [Palette.paper, Palette.paper.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 36)
                    .offset(y: 36)
                    .opacity(fade)
            }
            .allowsHitTesting(false)
    }

    // MARK: Form

    private var form: some View {
        VStack(spacing: 14) {
            titleSection
                .arrive(0)
            if model.isNew {
                PillPicker(options: EditorDraft.Kind.allCases, selection: kind) { Text($0.name) }
                    .arrive(1)
            }
            dateSection
                .arrive(2)
            EditorSection(title: "Style") {
                StylePicker(model: model)
                if model.draft.look == .dots {
                    DotOptionsView(draft: $model.draft)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .arrive(3)
            EditorSection(title: "Colour") {
                ThemeSwatches(theme: $model.draft.theme)
            }
            .arrive(4)
            if !model.isNew {
                Button("Delete tracker", role: .destructive) { confirmDelete = true }
                    .font(.rounded(15, .heavy))
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, wide ? 20 : 0)
        .padding(.bottom, 24)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .motion(Motion.gentle, value: model.draft.kind)
        .motion(Motion.gentle, value: model.draft.look)
        .motion(Motion.gentle, value: model.draft.period)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Name it", text: $model.draft.title)
                .font(.rounded(28, .black))
                .foregroundStyle(Palette.ink)
                .textFieldStyle(.plain)
                .focused($titleFocused)
                .submitLabel(.done)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Palette.tangerine, lineWidth: model.titleMissing ? 2.5 : 0)
                }
                .shake(titleShakes)
            if model.titleMissing {
                Label("Give it a name", systemImage: "exclamationmark.circle.fill")
                    .font(.rounded(13, .heavy))
                    .foregroundStyle(Palette.tangerine)
                    .padding(.leading, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .motion(Motion.snappy, value: model.titleMissing)
        .id("title")
    }

    @ViewBuilder private var dateSection: some View {
        switch model.draft.kind {
        case .countdown, .timeSince:
            EditorSection(title: model.draft.kind == .countdown ? "Date" : "Since") {
                DateControls(draft: $model.draft)
            }
        case .progress:
            EditorSection(title: "Range") {
                RangeControls(draft: $model.draft, invalid: model.rangeInvalid)
            }
            .id("range")
        }
    }

    private var kind: Binding<EditorDraft.Kind> {
        Binding(get: { model.draft.kind }, set: { model.setKind($0) })
    }

    // MARK: Save

    private var saveBar: some View {
        InkButton(title: model.isNew ? "Save" : "Done", systemImage: model.phase == .saved ? "checkmark" : nil) {
            titleFocused = false
            Task {
                guard await model.save() else { return }
                saveSucceeded += 1
                // Let the cat land on the card first.
                try? await Task.sleep(for: .milliseconds(800))
                close(saved: true)
            }
        }
        .disabled(model.phase != .editing)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Palette.paper.opacity(0), Palette.paper], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        )
    }

    private func close(saved: Bool) {
        finish(saved)
        dismiss()
    }
}

// MARK: - Date

private struct DateControls: View {
    @Binding var draft: EditorDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(draft.day, format: .dateTime.weekday(.abbreviated).day().month(.wide).year())
                        .font(.rounded(20, .black))
                        .contentTransition(.numericText())
                    Text(relative)
                        .font(.rounded(14, .bold))
                        .foregroundStyle(Palette.ink.opacity(0.55))
                        .contentTransition(.numericText())
                }
                .motion(Motion.snappy, value: draft.day)
                Spacer()
                DatePicker("Date", selection: $draft.day, displayedComponents: .date)
                    .labelsHidden()
            }
            DayScrubber(day: $draft.day)
                .padding(.horizontal, -18)
            HStack {
                Toggle(isOn: hasTime) {
                    Text("Exact time").font(.rounded(15, .heavy))
                }
                .toggleStyle(.switch)
                .fixedSize()
                Spacer()
                if let time = draft.time {
                    DatePicker("Time", selection: Binding(get: { time }, set: { draft.time = $0 }), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .trailing)))
                }
            }
            .motion(Motion.snappy, value: draft.time == nil)
        }
        .foregroundStyle(Palette.ink)
    }

    private var hasTime: Binding<Bool> {
        Binding(
            get: { draft.time != nil },
            set: { on in
                draft.time = on ? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: draft.day) : nil
                if !on { draft.zoneID = nil }
            }
        )
    }

    private var relative: String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: draft.day).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case -1: return "Yesterday"
        case 2...: return "in \(days) days"
        default: return "\(-days) days ago"
        }
    }
}

private struct RangeControls: View {
    @Binding var draft: EditorDraft
    var invalid: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PillPicker(options: EditorDraft.Period.allCases, selection: $draft.period) { Text($0.name) }
            if draft.period == .custom {
                VStack(spacing: 10) {
                    DatePicker("Starts", selection: $draft.rangeStart, displayedComponents: .date)
                    DatePicker("Ends", selection: $draft.rangeEnd, displayedComponents: .date)
                    if invalid || draft.rangeEnd < draft.rangeStart {
                        Label("The end must come after the start", systemImage: "exclamationmark.circle.fill")
                            .font(.rounded(13, .heavy))
                            .foregroundStyle(Palette.tangerine)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .font(.rounded(15, .heavy))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .foregroundStyle(Palette.ink)
    }
}

// MARK: - Dots

private struct DotOptionsView: View {
    @Binding var draft: EditorDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(WidgetContent.Dots.Shape.allCases, id: \.self) { shape in
                    Chip(selected: draft.dotShape == shape, action: { draft.dotShape = shape }) {
                        shapeIcon(shape).frame(width: 16, height: 16)
                    }
                    .accessibilityLabel(shapeName(shape))
                }
                Spacer(minLength: 0)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(EditorDraft.DotUnit.allCases) { unit in
                        Chip(selected: draft.dotUnit == unit, action: { draft.dotUnit = unit }) { Text(unit.name) }
                    }
                }
            }
            .scrollIndicators(.hidden)
            PillPicker(options: [true, false], selection: $draft.fillPast) { past in
                Text(past ? "Fill the past" : "Fill what's left")
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder private func shapeIcon(_ shape: WidgetContent.Dots.Shape) -> some View {
        switch shape {
        case .circle: Circle()
        case .square: RoundedRectangle(cornerRadius: 4)
        case .paw: PawPrint()
        }
    }

    private func shapeName(_ shape: WidgetContent.Dots.Shape) -> String {
        switch shape {
        case .circle: "Circles"
        case .square: "Squares"
        case .paw: "Paws"
        }
    }
}
