package com.drahanov.purrgets.domain.calc

import com.drahanov.purrgets.domain.model.ProgressRange
import kotlinx.datetime.DatePeriod
import kotlinx.datetime.DayOfWeek
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.atStartOfDayIn
import kotlinx.datetime.isoDayNumber
import kotlinx.datetime.minus
import kotlinx.datetime.plus
import kotlinx.datetime.toLocalDateTime
import kotlin.math.floor
import kotlin.time.Instant

data class ProgressBounds(
    val startDate: LocalDate,
    /** Exclusive. */
    val endDate: LocalDate,
    val start: Instant,
    val end: Instant,
)

data class ProgressValue(
    val bounds: ProgressBounds,
    val fraction: Double,
    /** Rounded down, so 100% only shows when the range is over. */
    val percent: Int,
)

object ProgressCalculator {

    fun calculate(
        range: ProgressRange,
        now: Instant,
        zone: TimeZone,
        firstDayOfWeek: DayOfWeek = DayOfWeek.MONDAY,
    ): ProgressValue {
        val bounds = bounds(range, now, zone, firstDayOfWeek)
        val fraction = fraction(bounds.start, bounds.end, now)
        return ProgressValue(bounds, fraction, percentOf(fraction))
    }

    fun bounds(
        range: ProgressRange,
        now: Instant,
        zone: TimeZone,
        firstDayOfWeek: DayOfWeek = DayOfWeek.MONDAY,
    ): ProgressBounds {
        val today = now.toLocalDateTime(zone).date
        return when (range) {
            ProgressRange.Year -> LocalDate(today.year, 1, 1).let {
                dateBounds(it, it.plus(DatePeriod(years = 1)), zone)
            }
            ProgressRange.Month -> LocalDate(today.year, today.month, 1).let {
                dateBounds(it, it.plus(DatePeriod(months = 1)), zone)
            }
            ProgressRange.Week -> {
                val offset = (today.dayOfWeek.isoDayNumber - firstDayOfWeek.isoDayNumber + 7) % 7
                val start = today.minus(DatePeriod(days = offset))
                dateBounds(start, start.plus(DatePeriod(days = 7)), zone)
            }
            is ProgressRange.Custom -> {
                val endDate = range.end.localDate(zone).plus(DatePeriod(days = 1))
                ProgressBounds(
                    startDate = range.start.localDate(zone),
                    endDate = endDate,
                    start = range.start.toInstant(zone),
                    end = if (range.end.time == null) endDate.atStartOfDayIn(zone) else range.end.toInstant(zone),
                )
            }
        }
    }

    private fun dateBounds(start: LocalDate, end: LocalDate, zone: TimeZone) =
        ProgressBounds(start, end, start.atStartOfDayIn(zone), end.atStartOfDayIn(zone))
}

internal fun percentOf(fraction: Double): Int = floor(fraction * 100 + 1e-9).toInt()
