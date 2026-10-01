package com.drahanov.purrgets.domain.engine

import com.drahanov.purrgets.domain.Kyiv
import com.drahanov.purrgets.domain.at
import com.drahanov.purrgets.domain.calc.CameoReason
import com.drahanov.purrgets.domain.calc.DotGridUnit
import com.drahanov.purrgets.domain.calc.DotLimits
import com.drahanov.purrgets.domain.date
import com.drahanov.purrgets.domain.model.CountdownStyle
import com.drahanov.purrgets.domain.model.Moment
import com.drahanov.purrgets.domain.model.ProgressRange
import com.drahanov.purrgets.domain.model.ProgressStyle
import com.drahanov.purrgets.domain.model.TimeSinceStyle
import com.drahanov.purrgets.domain.model.TrackerKind
import com.drahanov.purrgets.domain.tracker
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNotNull
import kotlin.test.assertNull

class TrackerEngineTest {
    private val engine = TrackerEngine()
    private val trip = TrackerKind.Countdown(Moment(date("2026-12-15")), CountdownStyle.Number)

    @Test
    fun countdownValue() {
        val state = engine.state(tracker(trip), at("2026-10-01T12:00"), Kyiv, DotLimits.SMALL)
        assertEquals(75, assertIs<TrackerValue.Countdown>(state.value).value.daysLeft)
        assertNull(state.dots)
    }

    @Test
    fun dotsOnlyForDotsStyle() {
        val dots = trip.copy(style = CountdownStyle.Dots())
        val state = engine.state(tracker(dots), at("2026-10-11T12:00"), Kyiv, DotLimits.SMALL)
        val grid = assertNotNull(state.dots)
        assertEquals(DotGridUnit.Day, grid.unit)
        assertEquals(75, grid.total)
        assertEquals(10, grid.elapsed)
    }

    @Test
    fun countdownMilestonesBringACat() {
        listOf("2026-12-14T12:00", "2026-12-08T12:00", "2026-11-07T12:00").forEach { now ->
            val state = engine.state(tracker(trip), at(now), Kyiv, DotLimits.SMALL)
            assertEquals(CameoReason.Milestone, state.cameo?.reason, now)
        }
    }

    @Test
    fun timeSinceDotsGoToNextMilestone() {
        val kind = TrackerKind.TimeSince(Moment(date("2026-09-01")), TimeSinceStyle.Dots())
        val state = engine.state(tracker(kind), at("2026-10-11T12:00"), Kyiv, DotLimits.SMALL)
        val grid = assertNotNull(state.dots)
        assertEquals(100, grid.total) // to day 100, 10 Dec
        assertEquals(40, grid.elapsed)
    }

    @Test
    fun progressHalfwayIsAMilestone() {
        val kind = TrackerKind.Progress(ProgressRange.Year, ProgressStyle.Number)
        val state = engine.state(tracker(kind), at("2026-07-02T15:00"), Kyiv, DotLimits.SMALL)
        assertEquals(CameoReason.Milestone, state.cameo?.reason)
    }
}
