package com.drahanov.purrgets.domain.calc

import com.drahanov.purrgets.domain.Kyiv
import com.drahanov.purrgets.domain.at
import com.drahanov.purrgets.domain.date
import com.drahanov.purrgets.domain.model.Moment
import com.drahanov.purrgets.domain.model.ProgressRange
import kotlinx.datetime.DayOfWeek
import kotlin.test.Test
import kotlin.test.assertEquals

class ProgressTest {

    private fun calc(range: ProgressRange, now: String) = ProgressCalculator.calculate(range, at(now), Kyiv)

    @Test
    fun year() {
        val value = calc(ProgressRange.Year, "2026-07-03T00:00")
        assertEquals(date("2026-01-01"), value.bounds.startDate)
        assertEquals(date("2027-01-01"), value.bounds.endDate)
        assertEquals(50, value.percent)
    }

    @Test
    fun yearStartsAtZero() {
        assertEquals(0, calc(ProgressRange.Year, "2026-01-01T00:00").percent)
    }

    @Test
    fun monthHandlesFebruaryInLeapYear() {
        val value = calc(ProgressRange.Month, "2028-02-15T00:00")
        assertEquals(date("2028-03-01"), value.bounds.endDate)
        assertEquals(48, value.percent) // 14 of 29 days
    }

    @Test
    fun weekStartsOnMondayByDefault() {
        // 2026-10-01 is a Thursday.
        assertEquals(date("2026-09-28"), calc(ProgressRange.Week, "2026-10-01T12:00").bounds.startDate)
        val sunday = ProgressCalculator.bounds(ProgressRange.Week, at("2026-10-01T12:00"), Kyiv, DayOfWeek.SUNDAY)
        assertEquals(date("2026-09-27"), sunday.startDate)
    }

    @Test
    fun customEndDateIsInclusive() {
        val range = ProgressRange.Custom(Moment(date("2026-10-01")), Moment(date("2026-10-10")))
        assertEquals(date("2026-10-11"), calc(range, "2026-10-05T00:00").bounds.endDate)
        assertEquals(40, calc(range, "2026-10-05T00:00").percent)
        assertEquals(100, calc(range, "2026-10-11T00:00").percent)
    }

    @Test
    fun percentRoundsDown() {
        assertEquals(99, calc(ProgressRange.Year, "2026-12-31T23:59").percent)
    }
}
