import WidgetKit

/// How many of the user's widgets show each tracker, as WidgetKit reports them.
enum WidgetCounts {
    static func current() async -> [String: Int] {
        let widgets = (try? await WidgetCenter.shared.currentConfigurations()) ?? []
        return widgets.reduce(into: [:]) { counts, widget in
            if let id = widget.widgetConfigurationIntent(of: SelectTrackerIntent.self)?.tracker?.id {
                counts[id, default: 0] += 1
            }
        }
    }
}
