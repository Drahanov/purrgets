package com.drahanov.purrgets.domain.engine

import com.drahanov.purrgets.domain.calc.CameoSchedule
import com.drahanov.purrgets.domain.calc.ProgressCalculator
import com.drahanov.purrgets.domain.calc.percentOf
import com.drahanov.purrgets.domain.model.Tracker
import com.drahanov.purrgets.domain.model.TrackerKind
import kotlinx.datetime.DatePeriod
import kotlinx.datetime.TimeZone
import kotlinx.datetime.atStartOfDayIn
import kotlinx.datetime.plus
import kotlinx.datetime.toLocalDateTime
import kotlin.time.Instant

/** When the widget needs a new frame, and when iOS should ask for the next plan. */
data class TimelinePlan(val moments: List<Instant>, val reloadAt: Instant)

/**
 * Plans frames from now until the second midnight ahead: every midnight (days change),
 * an exact countdown target, every moment a progress percent ticks over, and every cat move
 * (CameoSchedule.SLOT) on Number cards. Plans stay short ([maxEntries]) because WidgetKit renders every entry up front.
 */
class TimelinePlanner(
    private val engine: TrackerEngine,
    private val maxEntries: Int = DEFAULT_MAX_ENTRIES,
) {

    fun plan(tracker: Tracker, now: Instant, zone: TimeZone): TimelinePlan {
        val today = now.toLocalDateTime(zone).date
        val nextMidnight = today.plus(DatePeriod(days = 1)).atStartOfDayIn(zone)
        val horizon = today.plus(DatePeriod(days = 2)).atStartOfDayIn(zone)

        val candidates = mutableSetOf(now, nextMidnight)
        if (tracker.showsCameos) {
            var slot = CameoSchedule.slotStart(now) + CameoSchedule.SLOT
            while (slot < horizon) {
                candidates += slot
                slot += CameoSchedule.SLOT
            }
        }
        when (val kind = tracker.kind) {
            is TrackerKind.Countdown -> candidates += kind.target.toInstant(zone)
            is TrackerKind.TimeSince -> Unit
            is TrackerKind.Progress -> {
                val bounds = ProgressCalculator.bounds(kind.range, now, zone)
                candidates += bounds.end
                val span = bounds.end - bounds.start
                if (span.isPositive()) {
                    val current = percentOf(((now - bounds.start) / span).coerceIn(0.0, 1.0))
                    for (percent in (current + 1)..100) {
                        val moment = bounds.start + span * (percent / 100.0)
                        if (moment >= horizon) break
                        candidates += moment
                    }
                }
            }
        }

        val upcoming = candidates.filter { it >= now && it < horizon }.sorted()
        return if (upcoming.size > maxEntries) {
            TimelinePlan(upcoming.take(maxEntries), reloadAt = upcoming[maxEntries])
        } else {
            TimelinePlan(upcoming, reloadAt = horizon)
        }
    }

    companion object {
        const val DEFAULT_MAX_ENTRIES = 24
    }
}
