package com.drahanov.purrgets.domain.model

import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.LocalTime
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toInstant
import kotlinx.datetime.toLocalDateTime
import kotlin.time.Instant

/**
 * A date with an optional time.
 *
 * Floating (no [zone]): "15 Dec" is 15 Dec wherever the user is.
 * Fixed ([zone] set): an exact moment, e.g. a flight at 14:30 Kyiv time.
 */
data class Moment(
    val date: LocalDate,
    val time: LocalTime? = null,
    val zone: TimeZone? = null,
) {
    init {
        require(zone == null || time != null) { "A fixed time zone needs an exact time" }
    }

    fun toInstant(deviceZone: TimeZone): Instant =
        LocalDateTime(date, time ?: LocalTime(0, 0)).toInstant(zone ?: deviceZone)

    /** The calendar date this moment falls on, as seen in [deviceZone]. */
    fun localDate(deviceZone: TimeZone): LocalDate =
        if (zone == null) date else toInstant(deviceZone).toLocalDateTime(deviceZone).date
}
