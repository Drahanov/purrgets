import StoreKit
import SwiftUI

/// Settings: the cat, widgets help, support and about. A sheet from Home on iPhone,
/// the Settings window (⌘,) on the Mac.
struct SettingsView: View {
    @Environment(TrackerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.openWindow) private var openWindow
    @Environment(\.requestReview) private var requestReview
    @AppStorage("seenIntro") private var seenIntro = true
    @AppStorage("hideWidgetGuide") private var hideGuide = false

    @State private var showsGuide = false
    @State private var showsCats = false
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    group("Joe", index: 0) {
                        row("Replay intro", note: "He hangs from the top again. You pull.", icon: "arrow.counterclockwise", tint: Palette.tangerine) {
                            replayIntro()
                        }
                        #if DEBUG
                        divider
                        row("Cat show", note: "Every pose and cameo. Debug builds only.", icon: "pawprint.fill", tint: Palette.sand) {
                            showsCats = true
                        }
                        #endif
                    }

                    group("Widgets", index: 1) {
                        row("How to add a widget", note: Platform.isMac ? "On the desktop, step by step." : "Home Screen and Lock Screen, step by step.", icon: "plus.rectangle.on.rectangle", tint: Palette.marigold) {
                            showsGuide = true
                        }
                        divider
                        toggleRow("Show the guide after saving", icon: "sparkles", tint: Palette.marigold, isOn: .init(get: { !hideGuide }, set: { hideGuide = !$0 }))
                    }

                    group("Support", index: 2) {
                        row("Rate Purrgets", note: "Joe pretends not to care. He reads every one.", icon: "star.fill", tint: Palette.tangerine, trailing: "arrow.up.right") {
                            rate()
                        }
                        divider
                        row("Report a bug", note: "Opens an email with your device details filled in.", icon: "ladybug.fill", tint: Palette.sand, trailing: "arrow.up.right") {
                            mail(AppInfo.mail(subject: "Purrgets bug", diagnostics: store.trackers.count))
                        }
                        divider
                        row("Send feedback", note: "Ideas, wishes, kind words.", icon: "bubble.left.fill", tint: Palette.marigold, trailing: "arrow.up.right") {
                            mail(AppInfo.mail(subject: "Purrgets feedback"))
                        }
                        if let link = AppInfo.appStoreURL {
                            divider
                            ShareLink(item: link, message: Text("Countdowns with a cat in them.")) {
                                rowLabel("Tell a friend", note: nil, icon: "square.and.arrow.up", tint: Palette.tangerine, trailing: nil)
                            }
                            .buttonStyle(SquishStyle(scale: 0.98))
                        }
                    }

                    if AppInfo.privacyURL != nil || AppInfo.termsURL != nil {
                        group("About", index: 3) {
                            if let url = AppInfo.privacyURL {
                                row("Privacy policy", note: nil, icon: "hand.raised.fill", tint: Palette.sand, trailing: "arrow.up.right") { openURL(url) }
                            }
                            if AppInfo.privacyURL != nil, AppInfo.termsURL != nil { divider }
                            if let url = AppInfo.termsURL {
                                row("Terms of use", note: nil, icon: "doc.text.fill", tint: Palette.sand, trailing: "arrow.up.right") { openURL(url) }
                            }
                        }
                    }

                    SettingsFooter()
                        .modifier(ArriveModifier(index: 4))
                }
                .padding(18)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(Palette.paper.ignoresSafeArea())
            .navigationTitle("Settings")
            .inlineTitle()
            .toolbar {
                if !Platform.isMac {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: { Image(systemName: "xmark") }
                            .accessibilityLabel("Close")
                    }
                }
            }
            .overlay(alignment: .bottom) { toastView }
        }
        .tint(Palette.ink)
        .foregroundStyle(Palette.ink)
        .sheet(isPresented: $showsGuide) {
            AddWidgetGuide(cards: store.trackers.last.map { tracker in GuideCards { store.content(for: tracker, size: $0) } } ?? .sample) {
                hideGuide = true
            }
        }
        .sheet(isPresented: $showsCats) { CatShowView() }
        #if os(macOS)
        .frame(width: 480, height: 620)
        #endif
        .task { await store.load() }
    }

    // MARK: Actions

    private func replayIntro() {
        seenIntro = false
        if Platform.isMac {
            openWindow(id: Platform.mainWindow)
            Platform.activate()
        } else {
            dismiss()
        }
    }

    /// The App Store review page once there's an id; until then the system's review prompt.
    private func rate() {
        if let url = AppInfo.writeReviewURL {
            openURL(url)
        } else {
            requestReview()
        }
    }

    /// No mail app set up: the address goes on the clipboard instead.
    private func mail(_ url: URL?) {
        guard let url else { return }
        openURL(url) { opened in
            guard !opened else { return }
            if AppInfo.supportEmail.isEmpty {
                show("No mail app set up")
            } else {
                Platform.copy(AppInfo.supportEmail)
                show("Email address copied")
            }
        }
    }

    private func show(_ message: String) {
        withAnimation(Motion.bouncy) { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(Motion.gentle) { if toast == message { toast = nil } }
        }
    }

    // MARK: Pieces

    @ViewBuilder private var toastView: some View {
        if let toast {
            Text(toast)
                .font(.rounded(14, .heavy))
                .foregroundStyle(Palette.paper)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Palette.ink, in: Capsule())
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var divider: some View {
        Rectangle().fill(Palette.ink.opacity(0.08)).frame(height: 1).padding(.leading, 62)
    }

    private func group(_ title: String, index: Int, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.rounded(12, .heavy))
                .tracking(0.8)
                .foregroundStyle(Palette.ink.opacity(0.5))
                .padding(.leading, 6)
            VStack(spacing: 0) { content() }
                .padding(.vertical, 4)
                .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .modifier(ArriveModifier(index: index))
    }

    private func row(_ title: String, note: String?, icon: String, tint: Color, trailing: String? = "chevron.right", action: @escaping () -> Void) -> some View {
        Button(action: action) {
            rowLabel(title, note: note, icon: icon, tint: tint, trailing: trailing)
        }
        .buttonStyle(SquishStyle(scale: 0.98))
    }

    private func rowLabel(_ title: String, note: String?, icon: String, tint: Color, trailing: String?) -> some View {
        HStack(spacing: 14) {
            IconTile(icon: icon, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.rounded(16, .heavy))
                if let note {
                    Text(note).font(.rounded(13, .bold)).opacity(0.55)
                }
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            if let trailing {
                Image(systemName: trailing)
                    .font(.system(size: 13, weight: .heavy))
                    .opacity(0.35)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private func toggleRow(_ title: String, icon: String, tint: Color, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 14) {
                IconTile(icon: icon, tint: tint)
                Text(title).font(.rounded(16, .heavy))
            }
        }
        .toggleStyle(.switch)
        .tint(Palette.tangerine)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .sensoryFeedback(.selection, trigger: isOn.wrappedValue)
    }
}

/// A card-coloured square with an ink symbol, like a tiny widget.
private struct IconTile: View {
    var icon: String
    var tint: Color

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Palette.ink)
            .frame(width: 34, height: 34)
            .background(tint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Palette.ink.opacity(0.08), lineWidth: 1))
    }
}

/// Joe sits under the list, looks around and blinks. Tap him and he squashes.
private struct SettingsFooter: View {
    @State private var pokes = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 10) {
            TimelineView(.periodic(from: .now, by: 0.2)) { context in
                let ticks = Int(context.date.timeIntervalSinceReferenceDate / 0.2)
                CatArt(pose: .sitting, eyesClosed: ticks % 22 == 0, look: look(ticks))
                    .aspectRatio(CatArt.aspect(.sitting), contentMode: .fit)
                    .frame(height: 74)
                    .animation(Motion.gentle, value: look(ticks))
            }
            .keyframeAnimator(initialValue: 1.0, trigger: pokes) { view, stretch in
                view.scaleEffect(x: 2 - stretch, y: stretch, anchor: .bottom)
            } keyframes: { _ in
                KeyframeTrack {
                    SpringKeyframe(0.86, duration: 0.1)
                    SpringKeyframe(1.08, duration: 0.16)
                    SpringKeyframe(1, duration: 0.3)
                }
            }
            .onTapGesture { if !reduceMotion { pokes += 1 } }
            .sensoryFeedback(.impact(weight: .light), trigger: pokes)

            VStack(spacing: 2) {
                Text("Purrgets \(AppInfo.version) (\(AppInfo.build))").font(.rounded(13, .heavy))
                Text("Mr Joe Long keeps an eye on your days.").font(.rounded(12, .bold)).opacity(0.5)
            }
            .foregroundStyle(Palette.ink.opacity(0.7))
        }
        .padding(.top, 10)
        .frame(maxWidth: .infinity)
    }

    /// Ahead, left, ahead, right, every 3 s.
    private func look(_ ticks: Int) -> CGFloat {
        guard !reduceMotion else { return 0 }
        return [0, -1, 0, 1][(ticks / 15) % 4]
    }
}
