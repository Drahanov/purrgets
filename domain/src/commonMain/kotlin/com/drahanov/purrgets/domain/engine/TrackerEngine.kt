package com.drahanov.purrgets.domain.engine

import com.drahanov.purrgets.domain.calc.Cameo
import com.drahanov.purrgets.domain.calc.CameoSchedule
import com.drahanov.purrgets.domain.calc.CountdownCalculator
import com.drahanov.purrgets.domain.calc.CountdownStatus
import com.drahanov.purrgets.domain.calc.CountdownValue
import com.drahanov.purrgets.domain.calc.DotGrid
import com.drahanov.purrgets.domain.calc.DotGridCalculator
import com.drahanov.purrgets.domain.calc.ProgressCalculator
import com.drahanov.purrgets.domain.calc.ProgressValue
import com.drahanov.purrgets.domain.calc.TimeSinceCalculator
import com.drahanov.purrgets.domain.calc.TimeSinceValue
import com.drahanov.purrgets.domain.model.CountdownStyle
import com.drahanov.purrgets.domain.model.ProgressStyle
import com.drahanov.purrgets.domain.model.TimeSinceStyle
import com.drahanov.purrgets.domain.model.Tracker
import com.drahanov.purrgets.domain.model.TrackerKind
import kotlinx.datetime.DatePeriod
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.atStartOfDayIn
import kotlinx.datetime.daysUntil
import kotlinx.datetime.plus
import kotlinx.datetime.toLocalDateTime
import kotlin.time.Instant

/** Everything a view needs to draw a tracker at one moment. Views do no maths. */
data class TrackerState(
    val tracker: Tracker,
    val at: Instant,
    val value: TrackerValue,
    /** Only for the Dots style. */
    val dots: DotGrid?,
    /** Only while a cat is visiting. */
    val cameo: Cameo?,
)

sealed interface TrackerValue {
    data class Countdown(val value: CountdownValue) : TrackerValue
    data class TimeSince(val value: TimeSinceValue) : TrackerValue
    data class Progress(val value: ProgressValue) : TrackerValue
}

class TrackerEngine {

    fun state(tracker: Tracker, at: Instant, zone: TimeZone, maxDots: Int): TrackerState {
        val today = at.toLocalDateTime(zone).date
        val (value, dots) = when (val kind = tracker.kind) {
            is TrackerKind.Countdown -> {
                val value = CountdownCalculator.calculate(kind.target, tracker.createdAt, at, zone)
                val dots = (kind.style as? CountdownStyle.Dots)?.let {
                    val start = tracker.createdAt.toLocalDateTime(zone).date
                    DotGridCalculator.calculate(start, kind.target.localDate(zone), today, it.options, maxDots)
                }
                TrackerValue.Countdown(value) to dots
            }
            is TrackerKind.TimeSince -> {
                val value = TimeSinceCalculator.calculate(kind.start, at, zone)
                val dots = (kind.style as? TimeSinceStyle.Dots)?.let {
                    DotGridCalculator.calculate(kind.start.localDate(zone), value.nextMilestoneDate, today, it.options, maxDots)
                }
                TrackerValue.TimeSince(value) to dots
            }
            is TrackerKind.Progress -> {
                val value = ProgressCalculator.calculate(kind.range, at, zone)
                val dots = (kind.style as? ProgressStyle.Dots)?.let {
                    DotGridCalculator.calculate(value.bounds.startDate, value.bounds.endDate, today, it.options, maxDots)
                }
                TrackerValue.Progress(value) to dots
            }
        }
        val cameo = cameo(tracker, today, zone)?.takeIf { it.isVisibleAt(at) }
        return TrackerState(tracker, at, value, dots, cameo)
    }

    /** The cat visit planned for [date], visible or not. The planner uses it to add frames. */
    fun cameo(tracker: Tracker, date: LocalDate, zone: TimeZone): Cameo? =
        CameoSchedule.cameo(tracker.id, date, zone, isMilestoneDay(tracker, date, zone))

    /** 100 days left, 1 week left, tomorrow, halfway; or a time-since milestone. */
    private fun isMilestoneDay(tracker: Tracker, date: LocalDate, zone: TimeZone): Boolean {
        val dayStart = date.atStartOfDayIn(zone)
        return when (val kind = tracker.kind) {
            is TrackerKind.Countdown -> {
                val value = CountdownCalculator.calculate(kind.target, tracker.createdAt, dayStart, zone)
                val start = tracker.createdAt.toLocalDateTime(zone).date
                val halfway = start.plus(DatePeriod(days = start.daysUntil(kind.target.localDate(zone)) / 2))
                value.status == CountdownStatus.Tomorrow ||
                    (value.status == CountdownStatus.Upcoming && value.daysLeft in COUNTDOWN_MILESTONES) ||
                    (value.status != CountdownStatus.Passed && date == halfway && start < halfway)
            }
            is TrackerKind.TimeSince -> TimeSinceCalculator.calculate(kind.start, dayStart, zone).isMilestoneDay
            is TrackerKind.Progress -> {
                val bounds = ProgressCalculator.bounds(kind.range, dayStart, zone)
                (bounds.start + (bounds.end - bounds.start) / 2).toLocalDateTime(zone).date == date
            }
        }
    }

    private companion object {
        /** Days left that count as milestones: 100 days and 1 week. */
        val COUNTDOWN_MILESTONES = setOf(100, 7)
    }
}
