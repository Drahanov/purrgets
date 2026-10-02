import os

/// Cat logs, for watching widgets live:
/// `log stream --level info --predicate 'subsystem == "com.drahanov.purrgets"'`
enum CatLog {
    static let widget = Logger(subsystem: "com.drahanov.purrgets", category: "widget")
    static let app = Logger(subsystem: "com.drahanov.purrgets", category: "app")
}
