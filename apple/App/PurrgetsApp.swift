import SwiftUI
import WidgetKit

@main
struct PurrgetsApp: App {
    @State private var store = TrackerStore(container: Purrgets.container) {
        WidgetCenter.shared.reloadAllTimelines()
    }

    var body: some Scene {
        #if os(macOS)
        Window("Purrgets", id: Platform.mainWindow) {
            root
        }
        .defaultSize(width: 900, height: 700)

        MenuBarExtra("Purrgets", systemImage: "pawprint.fill") {
            MenuBarView()
                .environment(store)
                .preferredColorScheme(.light)
        }
        .menuBarExtraStyle(.window)
        #else
        WindowGroup {
            root
        }
        #endif
    }

    /// The design is warm and light only (DESIGN.md: never dark).
    private var root: some View {
        HomeView()
            .environment(store)
            .preferredColorScheme(.light)
            .tint(Palette.ink)
    }
}
