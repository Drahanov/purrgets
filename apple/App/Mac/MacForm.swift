#if os(macOS)
import Observation
import SwiftUI

/// Which sidebar page the main window shows. Shared, so ⌘, and the menu bar can open Settings in it.
@MainActor
@Observable
final class MacRouter {
    static let shared = MacRouter()
    var section: MacSection = .all

    /// Brings the main window forward on [section].
    static func show(_ section: MacSection, openWindow: OpenWindowAction) {
        shared.section = section
        openWindow(id: Platform.mainWindow)
        Platform.activate()
    }
}

extension View {
    /// The one look for every Mac form (editor, Settings): grouped rows on paper, rounded type,
    /// ink switches. Keeps the screens from drifting apart.
    func macFormStyle() -> some View {
        formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Palette.paper)
            .fontDesign(.rounded)
            // The Mac form ignores fontDesign for its rows; an explicit font reaches them.
            .font(.rounded(13, .semibold))
            .toggleStyle(.switch)
            .tint(Palette.ink)
            .foregroundStyle(Palette.ink)
    }
}

/// A form row with a card-coloured icon tile, a title, an optional note and a control on the right.
struct MacFormRow<Control: View>: View {
    var title: String
    var note: String?
    var icon: String
    var tint: Color
    @ViewBuilder var control: Control

    var body: some View {
        LabeledContent {
            control
        } label: {
            HStack(spacing: 12) {
                MacIconTile(icon: icon, tint: tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.rounded(13, .bold))
                    if let note { Text(note).font(.rounded(11, .semibold)).foregroundStyle(.secondary) }
                }
            }
        }
    }
}

/// The small coloured square used in the sidebar and in form rows.
struct MacIconTile: View {
    var icon: String
    var tint: Color

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(tint == Palette.ink ? Palette.paper : Palette.ink)
            .frame(width: 24, height: 24)
            .background(tint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Palette.ink.opacity(0.08), lineWidth: 1))
    }
}

/// ⌘, opens the Settings page in the main window instead of a separate window.
struct SettingsCommand: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Settings…") { MacRouter.show(.settings, openWindow: openWindow) }
            .keyboardShortcut(",")
    }
}
#endif
