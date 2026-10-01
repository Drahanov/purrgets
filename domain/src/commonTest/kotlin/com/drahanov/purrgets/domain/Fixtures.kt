package com.drahanov.purrgets.domain

import com.drahanov.purrgets.domain.model.Tracker
import com.drahanov.purrgets.domain.model.TrackerId
import com.drahanov.purrgets.domain.model.TrackerKind
import com.drahanov.purrgets.domain.repository.TrackerRepository
import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toInstant
import kotlin.time.Clock
import kotlin.time.Instant

val Kyiv = TimeZone.of("Europe/Kyiv")
val NewYork = TimeZone.of("America/New_York")

/** "2026-10-01T12:00" in [zone]. */
fun at(dateTime: String, zone: TimeZone = Kyiv): Instant = LocalDateTime.parse(dateTime).toInstant(zone)

fun date(text: String): LocalDate = LocalDate.parse(text)

fun tracker(
    kind: TrackerKind,
    createdAt: Instant = at("2026-10-01T09:00"),
    id: TrackerId = "tracker-1",
) = Tracker(id = id, title = "Test", kind = kind, createdAt = createdAt, updatedAt = createdAt)

class FixedClock(var now: Instant) : Clock {
    override fun now() = now
}

class FakeTrackerRepository : TrackerRepository {
    val trackers = mutableMapOf<TrackerId, Tracker>()

    override suspend fun all() = trackers.values.toList()
    override suspend fun get(id: TrackerId) = trackers[id]
    override suspend fun save(tracker: Tracker) {
        trackers[tracker.id] = tracker
    }
    override suspend fun delete(id: TrackerId) {
        trackers.remove(id)
    }
}
