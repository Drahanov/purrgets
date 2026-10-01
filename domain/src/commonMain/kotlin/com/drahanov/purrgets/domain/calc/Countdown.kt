package com.drahanov.purrgets.domain.calc

import com.drahanov.purrgets.domain.model.Moment
import kotlinx.datetime.TimeZone
import kotlinx.datetime.daysUntil
import kotlinx.datetime.toLocalDateTime
import kotlin.time.Instant

enum class CountdownStatus { Upcoming, Tomorrow, Today, Passed }

data class CountdownValue(
    val target: Instant,
    val daysLeft: Int,
    val daysPassed: Int,
    val status: CountdownStatus,
    /** 0 at creation, 1 at the target. */
    val fraction: Double,
)

object CountdownCalculator {

    fun calculate(target: Moment, createdAt: Instant, now: Instant, zone: TimeZone): CountdownValue {
        val targetInstant = target.toInstant(zone)
        val days = now.toLocalDateTime(zone).date.daysUntil(target.localDate(zone))
        val passed = if (target.time == null) days < 0 else now >= targetInstant
        val status = when {
            passed -> CountdownStatus.Passed
            days == 0 -> CountdownStatus.Today
            days == 1 -> CountdownStatus.Tomorrow
            else -> CountdownStatus.Upcoming
        }
        return CountdownValue(
            target = targetInstant,
            daysLeft = if (passed) 0 else days,
            daysPassed = if (passed) maxOf(-days, 0) else 0,
            status = status,
            fraction = fraction(createdAt, targetInstant, now),
        )
    }
}

internal fun fraction(start: Instant, end: Instant, now: Instant): Double = when {
    now >= end -> 1.0
    now <= start -> 0.0
    else -> ((now - start) / (end - start)).coerceIn(0.0, 1.0)
}
