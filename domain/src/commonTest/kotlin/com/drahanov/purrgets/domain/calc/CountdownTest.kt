package com.drahanov.purrgets.domain.calc

import com.drahanov.purrgets.domain.Kyiv
import com.drahanov.purrgets.domain.NewYork
import com.drahanov.purrgets.domain.at
import com.drahanov.purrgets.domain.date
import com.drahanov.purrgets.domain.model.Moment
import kotlinx.datetime.LocalTime
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class CountdownTest {
    private val created = at("2026-10-01T09:00")
    private val trip = Moment(date("2026-12-15"))

    private fun calc(target: Moment, now: String, zone: kotlinx.datetime.TimeZone = Kyiv) =
        CountdownCalculator.calculate(target, created, at(now, zone), zone)

    @Test
    fun countsCalendarDays() {
        val value = calc(trip, "2026-10-01T23:59")
        assertEquals(75, value.daysLeft)
        assertEquals(CountdownStatus.Upcoming, value.status)
    }

    @Test
    fun tomorrowTodayAndPassed() {
        assertEquals(CountdownStatus.Tomorrow, calc(trip, "2026-12-14T00:00").status)
        assertEquals(CountdownStatus.Today, calc(trip, "2026-12-15T23:59").status)
        val passed = calc(trip, "2026-12-18T10:00")
        assertEquals(CountdownStatus.Passed, passed.status)
        assertEquals(0, passed.daysLeft)
        assertEquals(3, passed.daysPassed)
    }

    @Test
    fun exactTimePassesDuringTheDay() {
        val flight = Moment(date("2026-12-15"), LocalTime(14, 30), Kyiv)
        assertEquals(CountdownStatus.Today, calc(flight, "2026-12-15T14:29").status)
        assertEquals(CountdownStatus.Passed, calc(flight, "2026-12-15T14:30").status)
    }

    @Test
    fun floatingDateIgnoresTravel() {
        // Same date in New York: still today, still 0 days left.
        val value = calc(trip, "2026-12-15T08:00", NewYork)
        assertEquals(CountdownStatus.Today, value.status)
    }

    @Test
    fun fixedTimeFollowsTheRealMoment() {
        // 14:30 Kyiv on 15 Dec is 07:30 in New York, so at 08:00 NY it has passed.
        val flight = Moment(date("2026-12-15"), LocalTime(14, 30), Kyiv)
        assertEquals(CountdownStatus.Passed, calc(flight, "2026-12-15T08:00", NewYork).status)
        assertEquals(CountdownStatus.Today, calc(flight, "2026-12-15T07:00", NewYork).status)
    }

    @Test
    fun daylightSavingDoesNotBreakDayCount() {
        // Kyiv moves clocks back on 25 Oct 2026.
        assertEquals(2, calc(Moment(date("2026-10-26")), "2026-10-24T12:00").daysLeft)
    }

    @Test
    fun fractionGoesFromCreationToTarget() {
        assertEquals(0.0, calc(trip, "2026-10-01T09:00").fraction)
        assertEquals(1.0, calc(trip, "2026-12-15T00:00").fraction)
    }

    @Test
    fun zoneNeedsExactTime() {
        assertFailsWith<IllegalArgumentException> { Moment(date("2026-12-15"), zone = Kyiv) }
    }
}
