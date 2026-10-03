import SwiftUI
import WidgetKit

@main
struct PurrgetsApp: App {
    @State private var store = TrackerStore(container: Purrgets.container, countWidgets: WidgetCounts.current) {
        WidgetCenter.shared.reloadAllTimelines()
    }

    var body: some Scene {
        #if os(macOS)
        Window("Purrgets", id: Platform.mainWindow) {
            root.frame(minWidth: 760, minHeight: 540)
        }
        .defaultSize(width: 1080, height: 740)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appSettings) { SettingsCommand() }
        }

        MenuBarExtra {
            MenuBarView()
                .environment(store)
                .preferredColorScheme(.light)
        } label: {
            // The app icon's cat ring as a template, so the menu bar tints it.
            Image("MenuBarCat").accessibilityLabel("Purrgets")
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
