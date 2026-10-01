package com.drahanov.purrgets

import com.drahanov.purrgets.data.calendar.EventKitCalendarSource

/** Entry point for Swift (Kotlin default arguments aren't visible there). Pass the App Group folder path. */
fun appleContainer(appGroupDirectory: String): AppContainer =
    AppContainer(appGroupDirectory, calendar = { EventKitCalendarSource() })
