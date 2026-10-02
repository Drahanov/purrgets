import SwiftUI

#if os(iOS)
import UIKit
#else
import AppKit
#endif

// The few places iOS and macOS differ, kept here so screens stay free of #if.

extension View {
    /// The card a sheet zooms out of (iOS 18). Nothing on the Mac.
    @ViewBuilder func zoomSource(_ id: String, in namespace: Namespace.ID) -> some View {
        #if os(iOS)
        matchedTransitionSource(id: id, in: namespace) { $0.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous)) }
        #else
        self
        #endif
    }

    /// Zooms this sheet out of its source card on iOS.
    @ViewBuilder func zoomTransition(_ id: String, in namespace: Namespace.ID) -> some View {
        #if os(iOS)
        navigationTransition(.zoom(sourceID: id, in: namespace))
        #else
        self
        #endif
    }

    /// Full screen on iPhone, a sheet on the Mac.
    func cover<Item: Identifiable, Content: View>(
        item: Binding<Item?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(iOS)
        fullScreenCover(item: item, onDismiss: onDismiss, content: content)
        #else
        sheet(item: item, onDismiss: onDismiss) { content($0).frame(minWidth: 760, minHeight: 620) }
        #endif
    }

    /// The shape the long-press preview lifts out (iOS only).
    @ViewBuilder func contextMenuShape(_ shape: some Shape) -> some View {
        #if os(iOS)
        contentShape(.contextMenuPreview, shape)
        #else
        self
        #endif
    }

    /// Inline title on iOS, ignored on the Mac.
    @ViewBuilder func inlineTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

enum Platform {
    /// The Mac's single main window, opened again from the menu bar.
    static let mainWindow = "main"

    static var isMac: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    static func copy(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    /// Brings the app to the front (the Mac can open windows from the menu bar or Settings).
    static func activate() {
        #if os(macOS)
        NSApp.activate()
        #endif
    }

    /// The system page where the user can turn calendar access back on.
    static func openCalendarSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        #else
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }
}
