package com.drahanov.purrgets.domain.usecase

import com.drahanov.purrgets.domain.TimeZoneProvider
import com.drahanov.purrgets.domain.engine.TimelinePlanner
import com.drahanov.purrgets.domain.engine.TrackerEngine
import com.drahanov.purrgets.domain.engine.TrackerState
import com.drahanov.purrgets.domain.model.TrackerId
import com.drahanov.purrgets.domain.repository.TrackerRepository
import kotlin.time.Clock
import kotlin.time.Instant

data class WidgetTimeline(val frames: List<TrackerState>, val reloadAt: Instant)

/**
 * What the widget asks for: frames for one tracker. Null if the tracker was deleted.
 * [cameos] is false for widget sizes that never draw a cat (Lock Screen), so they get no
 * 5-minute cat frames and reload far less often.
 */
class BuildWidgetTimeline(
    private val repository: TrackerRepository,
    private val planner: TimelinePlanner,
    private val engine: TrackerEngine,
    private val clock: Clock,
    private val zones: TimeZoneProvider,
) {
    @Throws(Exception::class)
    suspend operator fun invoke(id: TrackerId, maxDots: Int, cameos: Boolean): WidgetTimeline? {
        val saved = repository.get(id) ?: return null
        val tracker = if (cameos) saved else saved.copy(appearance = saved.appearance.copy(cameos = false))
        val zone = zones.current()
        val plan = planner.plan(tracker, clock.now(), zone)
        return WidgetTimeline(
            frames = plan.moments.map { engine.state(tracker, it, zone, maxDots) },
            reloadAt = plan.reloadAt,
        )
    }
}
