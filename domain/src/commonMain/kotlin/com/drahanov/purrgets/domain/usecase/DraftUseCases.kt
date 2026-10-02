package com.drahanov.purrgets.domain.usecase

import com.drahanov.purrgets.domain.TimeZoneProvider
import com.drahanov.purrgets.domain.model.CalendarEvent
import com.drahanov.purrgets.domain.model.CountdownStyle
import com.drahanov.purrgets.domain.model.Template
import com.drahanov.purrgets.domain.model.TrackerDraft
import com.drahanov.purrgets.domain.model.TrackerKind
import com.drahanov.purrgets.domain.repository.CalendarSource
import com.drahanov.purrgets.domain.repository.TemplateSource
import kotlinx.datetime.toLocalDateTime
import kotlin.time.Clock
import kotlin.time.Duration.Companion.days

class ListTemplates(
    private val source: TemplateSource,
    private val clock: Clock,
    private val zones: TimeZoneProvider,
) {
    operator fun invoke(): List<Template> = source.templates(clock.now().toLocalDateTime(zones.current()).date)
}

sealed interface CalendarResult {
    data class Events(val events: List<CalendarEvent>) : CalendarResult
    data object NoAccess : CalendarResult
}

/** Upcoming events to import, soonest first. */
class LoadCalendarEvents(
    private val source: CalendarSource,
    private val clock: Clock,
) {
    @Throws(Exception::class)
    suspend operator fun invoke(): CalendarResult {
        if (!source.requestAccess()) return CalendarResult.NoAccess
        val now = clock.now()
        return CalendarResult.Events(source.events(now, now + LOOK_AHEAD))
    }

    private companion object {
        val LOOK_AHEAD = 365.days
    }
}

/** A calendar event becomes a countdown to its start. */
class DraftFromEvent {
    operator fun invoke(event: CalendarEvent) = TrackerDraft(
        title = event.title,
        kind = TrackerKind.Countdown(event.moment, CountdownStyle.Number),
    )
}
