package com.drahanov.purrgets.domain.calc

import com.drahanov.purrgets.domain.at
import kotlin.time.Duration.Companion.minutes
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class CameoTest {
    private val start = at("2026-10-01T00:00")
    /** Two weeks of slots. */
    private fun day(trackerId: String = "tracker-1", milestone: Boolean = false) =
        (0 until 12 * 24 * 14).map { CameoSchedule.cameo(trackerId, start + CameoSchedule.SLOT * it, milestone) }

    @Test
    fun slotsAreFiveMinutesOnTheClock() {
        val cameo = CameoSchedule.cameo("a", at("2026-10-01T12:07"), false)
        assertEquals(at("2026-10-01T12:05"), cameo.from)
        assertEquals(at("2026-10-01T12:10"), cameo.until)
        assertEquals(5.minutes, CameoSchedule.SLOT)
    }

    @Test
    fun sameSlotGivesSameAnswer() {
        assertEquals(CameoSchedule.cameo("a", at("2026-10-01T12:06"), false), CameoSchedule.cameo("a", at("2026-10-01T12:09"), false))
    }

    @Test
    fun theCatMovesMostSlots() {
        val cameos = day()
        val repeats = cameos.zipWithNext().count { (a, b) -> a.pose == b.pose }
        assertTrue(repeats < cameos.size / 20, "repeats: $repeats of ${cameos.size}")
    }

    @Test
    fun everyPoseAndLookShowsUpAndSomeNaps() {
        val cameos = day()
        assertEquals(CameoPose.entries.toSet(), cameos.map { it.pose }.toSet())
        assertEquals(CameoLook.entries.toSet(), cameos.map { it.look }.toSet())
        val naps = cameos.count { it.eyesClosed }.toDouble() / cameos.size
        assertTrue(naps in 0.08..0.18, "naps: $naps")
    }

    @Test
    fun milestoneDaysArePawsEveryOtherSlot() {
        val cameos = day(milestone = true)
        assertTrue(cameos.all { it.reason == CameoReason.Milestone })
        assertTrue(cameos.zipWithNext().all { (a, b) -> a.pose == CameoPose.Paws || b.pose == CameoPose.Paws })
    }

    @Test
    fun trackersMoveOutOfStep() {
        assertTrue(day("a").map { it.pose } != day("b").map { it.pose })
    }
}
