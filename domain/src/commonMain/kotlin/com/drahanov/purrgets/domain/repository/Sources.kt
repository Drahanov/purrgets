package com.drahanov.purrgets.domain.repository

import com.drahanov.purrgets.domain.model.CalendarEvent
import com.drahanov.purrgets.domain.model.Template
import kotlinx.datetime.LocalDate
import kotlin.time.Instant

/** The device calendar. Implemented with EventKit on Apple platforms. */
interface CalendarSource {
    /** Asks the user for access. True if granted. */
    suspend fun requestAccess(): Boolean
    suspend fun events(from: Instant, until: Instant): List<CalendarEvent>
}

/** Built-in templates for the empty screen and the Library. */
interface TemplateSource {
    /** Dates are filled in relative to [today], e.g. the next Christmas. */
    fun templates(today: LocalDate): List<Template>
}
