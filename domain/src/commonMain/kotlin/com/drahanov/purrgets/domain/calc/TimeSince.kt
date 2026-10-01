package com.drahanov.purrgets.domain.calc

import com.drahanov.purrgets.domain.model.Moment
import kotlinx.datetime.DatePeriod
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.daysUntil
import kotlinx.datetime.periodUntil
import kotlinx.datetime.plus
import kotlinx.datetime.toLocalDateTime
import kotlin.time.Instant

/** 7, 30 and 100 days, then every year. */
sealed interface Milestone {
    fun dateFrom(start: LocalDate): LocalDate

    data class Days(val count: Int) : Milestone {
        override fun dateFrom(start: LocalDate) = start.plus(DatePeriod(days = count))
    }

    data class Years(val count: Int) : Milestone {
        override fun dateFrom(start: LocalDate) = start.plus(DatePeriod(years = count))
    }

    companion object {
        fun sequence(): Sequence<Milestone> =
            sequenceOf(Days(7), Days(30), Days(100)) + generateSequence(1) { it + 1 }.map(::Years)
    }
}

data class TimeSinceValue(
    val days: Int,
    /** For "1y 2m 5d". */
    val period: DatePeriod,
    val nextMilestone: Milestone,
    val nextMilestoneDate: LocalDate,
    /** Progress toward [nextMilestone], from the previous milestone (or the start). */
    val fraction: Double,
    val isMilestoneDay: Boolean,
    /** 0..1, how round the fat cat is. Grows until [FAT_CAT_FULL_DAYS] and never resets. */
    val fatCatGrowth: Double,
)

const val FAT_CAT_FULL_DAYS = 365

object TimeSinceCalculator {

    fun calculate(start: Moment, now: Instant, zone: TimeZone): TimeSinceValue {
        val startDate = start.localDate(zone)
        val today = maxOf(now.toLocalDateTime(zone).date, startDate)
        val days = startDate.daysUntil(today)

        var previousDate = startDate
        var isMilestoneDay = false
        val next = Milestone.sequence().first { milestone ->
            val date = milestone.dateFrom(startDate)
            if (date == today) isMilestoneDay = true
            if (date <= today) previousDate = date
            date > today
        }
        val nextDate = next.dateFrom(startDate)

        return TimeSinceValue(
            days = days,
            period = startDate.periodUntil(today),
            nextMilestone = next,
            nextMilestoneDate = nextDate,
            fraction = previousDate.daysUntil(today).toDouble() / previousDate.daysUntil(nextDate),
            isMilestoneDay = isMilestoneDay,
            fatCatGrowth = (days.toDouble() / FAT_CAT_FULL_DAYS).coerceAtMost(1.0),
        )
    }
}
