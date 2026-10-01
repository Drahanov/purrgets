package com.drahanov.purrgets.domain.usecase

import com.drahanov.purrgets.domain.FakeTrackerRepository
import com.drahanov.purrgets.domain.FixedClock
import com.drahanov.purrgets.domain.Kyiv
import com.drahanov.purrgets.domain.TimeZoneProvider
import com.drahanov.purrgets.domain.at
import com.drahanov.purrgets.domain.calc.DotLimits
import com.drahanov.purrgets.domain.date
import com.drahanov.purrgets.domain.engine.TimelinePlanner
import com.drahanov.purrgets.domain.engine.TrackerEngine
import com.drahanov.purrgets.domain.model.CountdownStyle
import com.drahanov.purrgets.domain.model.Moment
import com.drahanov.purrgets.domain.model.ProgressRange
import com.drahanov.purrgets.domain.model.ProgressStyle
import com.drahanov.purrgets.domain.model.TrackerKind
import com.drahanov.purrgets.domain.model.newTrackerId
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNotEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class UseCaseTest {
    private val repository = FakeTrackerRepository()
    private val clock = FixedClock(at("2026-10-01T12:00"))
    private val zones = TimeZoneProvider { Kyiv }
    private val save = SaveTracker(repository, clock, zones)
    private val trip = TrackerKind.Countdown(Moment(date("2026-12-15")), CountdownStyle.Number)

    @Test
    fun saveCreatesAndUpdateKeepsCreationTime() = runTest {
        val id = newTrackerId()
        val created = assertIs<SaveResult.Saved>(save(id, "  Trip  ", trip)).tracker
        assertEquals("Trip", created.title)
        assertEquals(clock.now, created.createdAt)

        clock.now = at("2026-10-05T12:00")
        val updated = assertIs<SaveResult.Saved>(save(id, "Lisbon", trip)).tracker
        assertEquals(created.createdAt, updated.createdAt)
        assertEquals(clock.now, updated.updatedAt)
        assertEquals(1, repository.trackers.size)
    }

    @Test
    fun invalidInputIsNotSaved() = runTest {
        val backwards = TrackerKind.Progress(
            ProgressRange.Custom(Moment(date("2026-10-10")), Moment(date("2026-10-01"))),
            ProgressStyle.Number,
        )
        val result = assertIs<SaveResult.Invalid>(save("id", " ", backwards))
        assertEquals(listOf(ValidationError.EmptyTitle, ValidationError.RangeEndsBeforeStart), result.errors)
        assertEquals(0, repository.trackers.size)
    }

    @Test
    fun listIsOldestFirst() = runTest {
        save("b", "Second", trip.copy())
        clock.now = at("2026-09-01T12:00")
        save("a", "First", trip)
        assertEquals(listOf("a", "b"), ListTrackers(repository)().map { it.id })
    }

    @Test
    fun deleteRemoves() = runTest {
        save("a", "Trip", trip)
        DeleteTracker(repository)("a")
        assertNull(repository.get("a"))
    }

    @Test
    fun widgetTimelineHasAFramePerPlannedMoment() = runTest {
        save("a", "Trip", trip)
        val build = BuildWidgetTimeline(repository, TimelinePlanner(TrackerEngine()), TrackerEngine(), clock, zones)
        val timeline = assertNotNull(build("a", DotLimits.SMALL))
        val frames = timeline.frames.map { it.at }
        assertEquals(clock.now, frames.first())
        assertTrue(at("2026-10-02T00:00") in frames)
        assertNull(build("deleted", DotLimits.SMALL))
    }

    @Test
    fun idsAreUnique() {
        assertNotEquals(newTrackerId(), newTrackerId())
    }
}
