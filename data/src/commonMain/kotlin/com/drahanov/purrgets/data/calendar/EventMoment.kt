package com.drahanov.purrgets.data.calendar

import com.drahanov.purrgets.domain.model.Moment
import kotlinx.datetime.LocalTime
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toLocalDateTime
import kotlin.time.Instant

/**
 * Turns a calendar event's start into a [Moment]:
 * - all-day event → floating date
 * - timed event with a time zone → fixed time in that zone
 * - timed event without one (floating in the calendar) → floating date and time
 */
internal fun eventMoment(start: Instant, isAllDay: Boolean, eventZoneId: String?, deviceZone: TimeZone): Moment {
    val eventZone = eventZoneId?.let(TimeZone::of)
    val local = start.toLocalDateTime(eventZone ?: deviceZone)
    return when {
        isAllDay -> Moment(local.date)
        else -> Moment(local.date, LocalTime(local.hour, local.minute), eventZone)
    }
}
