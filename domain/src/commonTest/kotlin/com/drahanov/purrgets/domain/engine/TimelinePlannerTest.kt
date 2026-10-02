package com.drahanov.purrgets.domain.engine

import com.drahanov.purrgets.domain.Kyiv
import com.drahanov.purrgets.domain.at
import com.drahanov.purrgets.domain.calc.CameoSchedule
import com.drahanov.purrgets.domain.calc.DotLimits
import com.drahanov.purrgets.domain.date
import com.drahanov.purrgets.domain.model.CountdownStyle
import com.drahanov.purrgets.domain.model.Moment
import com.drahanov.purrgets.domain.model.ProgressRange
import com.drahanov.purrgets.domain.model.ProgressStyle
import com.drahanov.purrgets.domain.model.TimeSinceStyle
import com.drahanov.purrgets.domain.model.Tracker
import com.drahanov.purrgets.domain.model.TrackerKind
import com.drahanov.purrgets.domain.tracker
import kotlinx.datetime.LocalTime
import kotlin.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class TimelinePlannerTest {
    private val engine = TrackerEngine()
    private val planner = TimelinePlanner(engine)
    private val now = at("2026-10-01T12:00")
    private val horizon = at("2026-10-03T00:00")

    /** Cat moves (every slot on Number cards) the planner adds on top of the others. */
    private fun cameoMoments(t: Tracker) =
        if (t.showsCameos) generateSequence(now + CameoSchedule.SLOT) { it + CameoSchedule.SLOT }.takeWhile { it < horizon }.toList()
        else emptyList()

    /** The first frames of the plan: the planner cuts plans at maxEntries. */
    private fun expected(t: Tracker, vararg moments: Instant) =
        (moments.toList() + cameoMoments(t)).distinct().sorted().take(TimelinePlanner.DEFAULT_MAX_ENTRIES)

    @Test
    fun dateCountdownChangesAtMidnight() {
        val kind = TrackerKind.Countdown(Moment(date("2026-12-15")), CountdownStyle.Number)
        val t = tracker(kind)
        val plan = planner.plan(t, now, Kyiv)
        assertEquals(expected(t, now, at("2026-10-02T00:00")), plan.moments)
        // A cat move every 5 minutes fills the plan in 2 hours.
        assertEquals(at("2026-10-01T14:00"), plan.reloadAt)
    }

    @Test
    fun cardsWithoutCatsOnlyChangeAtMidnight() {
        val t = tracker(TrackerKind.Countdown(Moment(date("2026-12-15")), CountdownStyle.Ring))
        val plan = planner.plan(t, now, Kyiv)
        assertEquals(listOf(now, at("2026-10-02T00:00")), plan.moments)
        assertEquals(horizon, plan.reloadAt)
    }

    @Test
    fun exactCountdownGetsAFrameAtTheTarget() {
        val kind = TrackerKind.Countdown(Moment(date("2026-10-01"), LocalTime(14, 30), Kyiv), CountdownStyle.Number)
        val t = tracker(kind)
        val plan = planner.plan(t, now, Kyiv)
        assertEquals(expected(t, now, at("2026-10-01T14:30"), at("2026-10-02T00:00")), plan.moments)
    }

    @Test
    fun weekProgressGetsAFramePerPercent() {
        val kind = TrackerKind.Progress(ProgressRange.Week, ProgressStyle.Number)
        val t = tracker(kind)
        val plan = planner.plan(t, now, Kyiv)
        val percents = plan.moments.map {
            assertIs<TrackerValue.Progress>(engine.state(t, it, Kyiv, DotLimits.SMALL).value).value.percent
        }
        // Thursday noon is 50%. Each percent frame must already show the new percent.
        assertEquals(50, percents.first())
        val other = setOf(now, at("2026-10-02T00:00")) + cameoMoments(t)
        plan.moments.indices.drop(1).filter { plan.moments[it] !in other }.forEach {
            assertEquals(percents[it - 1] + 1, percents[it], "frame at ${plan.moments[it]}")
        }
    }

    @Test
    fun longPlansAreCut() {
        val range = ProgressRange.Custom(
            Moment(date("2026-10-01"), LocalTime(12, 0)),
            Moment(date("2026-10-01"), LocalTime(13, 0)),
        )
        val plan = planner.plan(tracker(TrackerKind.Progress(range, ProgressStyle.Number)), now, Kyiv)
        assertEquals(TimelinePlanner.DEFAULT_MAX_ENTRIES, plan.moments.size)
        assertTrue(plan.moments.zipWithNext().all { (a, b) -> a < b })
        assertTrue(plan.reloadAt > plan.moments.last())
    }
}
