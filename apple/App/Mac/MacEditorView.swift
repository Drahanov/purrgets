#if os(macOS)
import SwiftUI

/// The editor as a Mac sheet: the live widget sits on a little desktop on the left,
/// a native form fills the right, and Cancel / Save sit at the bottom like any Mac sheet.
/// Same view model as the phone editor; only the layout and controls differ.
struct MacEditorView: View {
    @State private var model: EditorViewModel
    private let finish: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var titleShakes = 0
    @FocusState private var titleFocused: Bool

    init(store: TrackerStore, request: EditorRequest, finish: @escaping (Bool) -> Void) {
        _model = State(initialValue: EditorViewModel(store: store, draft: request.draft, trackerID: request.trackerID))
        self.finish = finish
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                MacPreviewStage(model: model)
                    .frame(width: 400)
                Divider()
                form
                    .frame(width: 499)
            }
            Divider()
            footer
        }
        .frame(width: 900, height: 640)
        .background(Palette.paper)
        .fontDesign(.rounded)
        .foregroundStyle(Palette.ink)
        .tint(Palette.ink)
        .onAppear { if model.isNew { titleFocused = true } }
        .onChange(of: model.shakes) {
            titleShakes += 1
            if model.titleMissing { titleFocused = true }
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
        .alert("Couldn't save", isPresented: $model.saveFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your changes are still here. Please try again.")
        }
    }

    // MARK: Form

    private var form: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.isNew ? "New \(model.draft.kind.name.lowercased())" : "Edit tracker")
                        .font(.rounded(22, .black))
                        .contentTransition(.opacity)
                    Text(intro)
                        .font(.rounded(13, .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                TextField("Name", text: $model.draft.title, prompt: Text(model.draft.placeholderTitle))
                    .focused($titleFocused)
                    .shake(titleShakes)
                if model.isNew {
                    Picker("Type", selection: kind) {
                        ForEach(EditorDraft.Kind.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            } footer: {
                if model.titleMissing {
                    Label("Give it a name", systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(Palette.tangerine)
                        .font(.rounded(12, .heavy))
                }
            }

            dateSection

            Section("Style") {
                MacStyleGrid(model: model)
                if model.draft.look == .dots { dotOptions }
                LabeledContent("Colour") { MacSwatches(theme: $model.draft.theme) }
            }

            Section {
                HStack(alignment: .center, spacing: 14) {
                    CameoReel(content: model.content(look: .number), on: model.draft.cameos)
                        .scaleEffect(0.7)
                        .frame(width: 72, height: 72)
                    Toggle(isOn: $model.draft.cameos) {
                        Text("Let Mr Joe Long drop by")
                        Text("Now and then he hangs off the top of your Number widget, strolls past or waves his tail.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if model.draft.cameos, model.draft.look != .number {
                    LabeledContent {
                        Button("Use Number") { withAnimation(Motion.bouncy) { model.setLook(.number) } }
                    } label: {
                        Label("He only visits Number cards", systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Visitor")
            }
        }
        .macFormStyle()
        .motion(Motion.gentle, value: model.draft.kind)
        .motion(Motion.gentle, value: model.draft.look)
        .motion(Motion.gentle, value: model.draft.period)
        .motion(Motion.snappy, value: model.titleMissing)
    }

    @ViewBuilder private var dateSection: some View {
        switch model.draft.kind {
        case .countdown, .timeSince:
            Section(model.draft.kind == .countdown ? "Date" : "Since") {
                LabeledContent {
                    DatePicker("Date", selection: $model.draft.day, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.stepperField)
                } label: {
                    Text(model.draft.kind == .countdown ? "Counts down to" : "Counts from")
                    Text(relative).font(.rounded(11, .semibold)).foregroundStyle(.secondary).contentTransition(.numericText())
                }
                Toggle("Exact time", isOn: hasTime)
                if let time = model.draft.time {
                    DatePicker("Time", selection: Binding(get: { time }, set: { model.draft.time = $0 }), displayedComponents: .hourAndMinute)
                }
            }
            .motion(Motion.snappy, value: model.draft.time == nil)
        case .progress:
            Section {
                Picker("Period", selection: $model.draft.period) {
                    ForEach(EditorDraft.Period.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                if model.draft.period == .custom {
                    DatePicker("Starts", selection: $model.draft.rangeStart, displayedComponents: .date)
                    DatePicker("Ends", selection: $model.draft.rangeEnd, displayedComponents: .date)
                }
            } header: {
                Text("Range")
            } footer: {
                if model.draft.period == .custom, model.rangeInvalid || model.draft.rangeEnd < model.draft.rangeStart {
                    Label("The end must come after the start", systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(Palette.tangerine)
                        .font(.rounded(12, .heavy))
                }
            }
        }
    }

    @ViewBuilder private var dotOptions: some View {
        Picker("Dot shape", selection: $model.draft.dotShape) {
            Text("Circles").tag(WidgetContent.Dots.Shape.circle)
            Text("Squares").tag(WidgetContent.Dots.Shape.square)
            Text("Paws").tag(WidgetContent.Dots.Shape.paw)
        }
        .pickerStyle(.segmented)
        Picker("One dot per", selection: $model.draft.dotUnit) {
            ForEach(EditorDraft.DotUnit.allCases) { unit in
                Text(unit == .auto ? "Best fit" : String(unit.name.dropLast())).tag(unit)
            }
        }
        Picker("Fill", selection: $model.draft.fillPast) {
            Text("The past").tag(true)
            Text("What's left").tag(false)
        }
        .pickerStyle(.segmented)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 10) {
            if !model.isNew {
                Button("Delete…", role: .destructive) { confirmDelete = true }
            }
            Spacer()
            if model.phase == .saved {
                Label("Saved", systemImage: "checkmark.circle.fill")
                    .font(.rounded(13, .heavy))
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
            Button("Cancel") { close(saved: false) }
                .keyboardShortcut(.cancelAction)
            Button(model.isNew ? "Add tracker" : "Save") { save() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(model.phase != .editing)
        }
        .controlSize(.large)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .motion(Motion.snappy, value: model.phase)
    }

    // MARK: Actions

    private func save() {
        titleFocused = false
        Task {
            guard await model.save() else { return }
            // Let the cat land on the card first.
            try? await Task.sleep(for: .milliseconds(800))
            close(saved: true)
        }
    }

    private func close(saved: Bool) {
        finish(saved)
        dismiss()
    }

    private var kind: Binding<EditorDraft.Kind> {
        Binding(get: { model.draft.kind }, set: { model.setKind($0) })
    }

    private var hasTime: Binding<Bool> {
        Binding(
            get: { model.draft.time != nil },
            set: { on in
                model.draft.time = on ? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: model.draft.day) : nil
                if !on { model.draft.zoneID = nil }
            }
        )
    }

    private var intro: String {
        switch model.draft.kind {
        case .countdown: "Days until a date, right on your desktop."
        case .timeSince: "Days since something began."
        case .progress: "How much of the year, month, week or a range has gone."
        }
    }

    private var relative: String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: model.draft.day).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case -1: return "Yesterday"
        case 2...: return "In \(days) days"
        default: return "\(-days) days ago"
        }
    }
}

// MARK: - Preview

/// The widget on a small desktop: a soft wallpaper, the card floating on it, Small / Medium below.
private struct MacPreviewStage: View {
    @Bindable var model: EditorViewModel
    @State private var bounces = 0

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            ZStack {
                Wallpaper()
                TimelineView(.everyMinute) { _ in
                    LiveCard(content: model.content(size: model.previewSize), size: model.previewSize)
                        .frame(width: model.previewSize.previewSize.width, height: model.previewSize.previewSize.height)
                        .overlay(alignment: .topTrailing) {
                            if model.phase == .saved {
                                HoppingCat(size: 46).offset(x: -26, y: -38)
                            }
                        }
                        .shadow(color: Palette.ink.opacity(0.22), radius: 20, y: 12)
                        .id(model.previewSize)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
                .keyframeAnimator(initialValue: 1.0, trigger: bounces) { view, scale in
                    view.scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(0.95, duration: 0.1)
                        SpringKeyframe(1.0, duration: 0.45, spring: .bouncy(extraBounce: 0.2))
                    }
                }
            }
            .frame(width: 368, height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Palette.ink.opacity(0.08), lineWidth: 1))

            Picker("Size", selection: $model.previewSize.animation(Motion.gentle)) {
                ForEach(model.sizes, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 200)

            Text("Live preview. Add it from the desktop: right-click, Edit Widgets.")
                .font(.rounded(12, .bold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(width: 280)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.ink.opacity(0.03))
        .onChange(of: lookKey) { bounces += 1 }
    }

    private var lookKey: String {
        let draft = model.draft
        return "\(draft.kind)-\(draft.look)-\(draft.theme)-\(draft.period)-\(draft.dotShape)-\(draft.dotUnit)-\(draft.fillPast)"
    }
}

/// A calm desktop picture for the preview: warm sky and two soft hills.
private struct Wallpaper: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [Color(hex: 0xF3E3C8), Color(hex: 0xEACB9B)], startPoint: .top, endPoint: .bottom)
            Ellipse().fill(Color(hex: 0xE2B676).opacity(0.7)).frame(width: 520, height: 180).offset(x: -140, y: 90)
            Ellipse().fill(Color(hex: 0xD9A262).opacity(0.6)).frame(width: 480, height: 160).offset(x: 170, y: 100)
        }
    }
}

// MARK: - Style grid

/// Every style as a small widget of this tracker, in a grid. Click one to switch.
private struct MacStyleGrid: View {
    var model: EditorViewModel
    @Namespace private var outline

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84, maximum: 96), spacing: 12)], spacing: 12) {
            ForEach(Array(model.draft.looks.enumerated()), id: \.element) { index, look in
                let selected = model.draft.look == look
                Button {
                    withAnimation(Motion.bouncy) { model.setLook(look) }
                } label: {
                    VStack(spacing: 6) {
                        LiveCard(content: model.content(look: look), size: .small, index: index)
                            .frame(width: 170, height: 170)
                            .scaleEffect(0.44)
                            .frame(width: 75, height: 75)
                            .padding(4)
                            .overlay {
                                if selected {
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .stroke(Palette.ink, lineWidth: 2.5)
                                        .matchedGeometryEffect(id: "outline", in: outline)
                                }
                            }
                        Text(look.name)
                            .font(.rounded(12, selected ? .heavy : .bold))
                            .foregroundStyle(selected ? Palette.ink : .secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(SquishStyle(scale: 0.94))
                .hoverLift()
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

/// The four card colours as small dots, like the accent colours in System Settings.
private struct MacSwatches: View {
    @Binding var theme: CardTheme

    var body: some View {
        HStack(spacing: 8) {
            ForEach(CardTheme.allCases, id: \.self) { option in
                Button {
                    withAnimation(Motion.snappy) { theme = option }
                } label: {
                    Circle()
                        .fill(option.background)
                        .overlay(Circle().stroke(Palette.ink.opacity(0.15), lineWidth: 1))
                        .overlay {
                            if option == theme {
                                Circle().fill(Palette.ink).frame(width: 6, height: 6)
                            }
                        }
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help(option.name)
                .accessibilityLabel(option.name)
                .accessibilityAddTraits(option == theme ? .isSelected : [])
            }
        }
    }
}
#endif
