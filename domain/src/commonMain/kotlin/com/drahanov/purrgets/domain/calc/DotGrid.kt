package com.drahanov.purrgets.domain.calc

import com.drahanov.purrgets.domain.model.DotOptions
import com.drahanov.purrgets.domain.model.DotUnit
import kotlinx.datetime.DatePeriod
import kotlinx.datetime.LocalDate
import kotlinx.datetime.daysUntil
import kotlinx.datetime.monthsUntil
import kotlinx.datetime.plus
import kotlinx.datetime.yearsUntil

object DotLimits {
    const val SMALL = 100
    const val MEDIUM = 200
}

enum class DotGridUnit { Day, Week, Month, Year }

data class DotGrid(
    val unit: DotGridUnit,
    val total: Int,
    /** Units already passed, counted from the first dot. */
    val elapsed: Int,
    val fillPast: Boolean,
) {
    fun isFilled(index: Int): Boolean = if (fillPast) index < elapsed else index >= elapsed
}

object DotGridCalculator {

    /**
     * One dot per unit between [start] and [end] (exclusive). If the chosen unit needs more
     * than [maxDots], the next bigger unit is used.
     */
    fun calculate(start: LocalDate, end: LocalDate, today: LocalDate, options: DotOptions, maxDots: Int): DotGrid {
        val preferred = when (options.unit) {
            DotUnit.Auto, DotUnit.Day -> DotGridUnit.Day
            DotUnit.Week -> DotGridUnit.Week
            DotUnit.Month -> DotGridUnit.Month
        }
        val unit = DotGridUnit.entries
            .drop(preferred.ordinal)
            .firstOrNull { total(it, start, end) <= maxDots }
            ?: DotGridUnit.Year
        val total = total(unit, start, end).coerceAtMost(maxDots)
        val elapsed = elapsed(unit, start, today).coerceIn(0, total)
        return DotGrid(unit, total, elapsed, options.fillPast)
    }

    private fun total(unit: DotGridUnit, start: LocalDate, end: LocalDate): Int {
        if (end <= start) return 0
        return when (unit) {
            DotGridUnit.Day -> start.daysUntil(end)
            DotGridUnit.Week -> (start.daysUntil(end) + 6) / 7
            DotGridUnit.Month -> start.monthsUntil(end).let { if (start.plus(DatePeriod(months = it)) < end) it + 1 else it }
            DotGridUnit.Year -> start.yearsUntil(end).let { if (start.plus(DatePeriod(years = it)) < end) it + 1 else it }
        }
    }

    private fun elapsed(unit: DotGridUnit, start: LocalDate, today: LocalDate): Int {
        if (today <= start) return 0
        return when (unit) {
            DotGridUnit.Day -> start.daysUntil(today)
            DotGridUnit.Week -> start.daysUntil(today) / 7
            DotGridUnit.Month -> start.monthsUntil(today)
            DotGridUnit.Year -> start.yearsUntil(today)
        }
    }
}
