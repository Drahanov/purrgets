package com.drahanov.purrgets.domain.calc

import com.drahanov.purrgets.domain.Kyiv
import com.drahanov.purrgets.domain.at
import com.drahanov.purrgets.domain.date
import kotlinx.datetime.DatePeriod
import kotlinx.datetime.plus
import kotlinx.datetime.toLocalDateTime
import kotlin.time.Duration.Companion.hours
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class CameoTest {
    private val start = date("2026-01-01")
    private val days = (0 until 3000).map { start.plus(DatePeriod(days = it)) }

    private fun random(trackerId: String = "tracker-1") =
        days.mapNotNull { CameoSchedule.cameo(trackerId, it, Kyiv, isMilestoneDay = false) }

    @Test
    fun milestoneDayIsAPeekAllDay() {
        val cameo = assertNotNull(CameoSchedule.cameo("a", date("2026-10-01"), Kyiv, isMilestoneDay = true))
        assertEquals(CameoReason.Milestone, cameo.reason)
        assertEquals(CameoPose.Peek, cameo.pose)
        assertEquals(at("2026-10-01T00:00"), cameo.from)
        assertEquals(at("2026-10-02T00:00"), cameo.until)
    }

    @Test
    fun sameDayGivesSameAnswer() {
        val day = date("2026-10-01")
        assertEquals(CameoSchedule.cameo("a", day, Kyiv, false), CameoSchedule.cameo("a", day, Kyiv, false))
    }

    @Test
    fun randomDaysAreTwoOrThreeAWeek() {
        val perWeek = random().size * 7.0 / days.size
        assertTrue(perWeek in 2.0..2.7, "per week was $perWeek")
    }

    @Test
    fun randomVisitsLastTwoToFourHoursInMorningAfternoonOrEvening() {
        random().forEach {
            assertTrue((it.until - it.from) in 2.hours..4.hours)
            assertTrue(it.from.toLocalDateTime(Kyiv).hour in setOf(8, 13, 18))
        }
    }

    @Test
    fun everyPoseShowsUp() {
        val visits = random()
        assertEquals(CameoPose.entries.toSet(), visits.map { it.pose }.toSet())
        assertEquals(setOf(8, 13, 18), visits.map { it.from.toLocalDateTime(Kyiv).hour }.toSet())
    }

    @Test
    fun trackersGetDifferentDays() {
        assertTrue(random("a").map { it.from } != random("b").map { it.from })
    }
}
