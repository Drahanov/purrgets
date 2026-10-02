package com.drahanov.purrgets.domain.calc

import com.drahanov.purrgets.domain.Kyiv
import com.drahanov.purrgets.domain.at
import com.drahanov.purrgets.domain.date
import com.drahanov.purrgets.domain.model.Moment
import kotlinx.datetime.DatePeriod
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class TimeSinceTest {
    private val start = Moment(date("2025-08-01"))

    private fun calc(now: String) = TimeSinceCalculator.calculate(start, at(now), Kyiv)

    @Test
    fun daysAndPeriod() {
        val value = calc("2026-10-06T12:00")
        assertEquals(431, value.days)
        assertEquals(DatePeriod(years = 1, months = 2, days = 5), value.period)
    }

    @Test
    fun milestonesGoSevenThirtyHundredThenYears() {
        assertEquals(Milestone.Days(7), calc("2025-08-03T12:00").nextMilestone)
        assertEquals(Milestone.Days(30), calc("2025-08-08T12:00").nextMilestone)
        assertEquals(Milestone.Days(100), calc("2025-09-15T12:00").nextMilestone)
        assertEquals(Milestone.Years(1), calc("2025-12-01T12:00").nextMilestone)
        assertEquals(Milestone.Years(2), calc("2026-10-01T12:00").nextMilestone)
    }

    @Test
    fun fractionIsFromPreviousMilestone() {
        // Between day 7 (08-08) and day 30 (08-31): 23 days, 10 done.
        assertEquals(10.0 / 23, calc("2025-08-18T12:00").fraction)
    }

    @Test
    fun milestoneDay() {
        assertTrue(calc("2025-08-08T00:00").isMilestoneDay)
        assertTrue(calc("2026-08-01T12:00").isMilestoneDay)
        assertFalse(calc("2025-08-09T12:00").isMilestoneDay)
    }

    @Test
    fun futureStartCountsAsZero() {
        val value = calc("2025-07-20T12:00")
        assertEquals(0, value.days)
        assertEquals(0.0, value.fraction)
    }

}
