package com.drahanov.purrgets.domain.calc

import com.drahanov.purrgets.domain.date
import com.drahanov.purrgets.domain.model.DotOptions
import com.drahanov.purrgets.domain.model.DotUnit
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class DotGridTest {

    private fun grid(start: String, end: String, today: String, options: DotOptions = DotOptions(), max: Int = DotLimits.SMALL) =
        DotGridCalculator.calculate(date(start), date(end), date(today), options, max)

    @Test
    fun oneDotPerDay() {
        val grid = grid("2026-10-01", "2026-10-31", "2026-10-11")
        assertEquals(DotGridUnit.Day, grid.unit)
        assertEquals(30, grid.total)
        assertEquals(10, grid.elapsed)
    }

    @Test
    fun switchesToWeeksAboveTheLimit() {
        val year = grid("2026-01-01", "2027-01-01", "2026-03-01")
        assertEquals(DotGridUnit.Week, year.unit)
        assertEquals(53, year.total)
        assertEquals(8, year.elapsed)
    }

    @Test
    fun mediumFitsMoreDays() {
        assertEquals(DotGridUnit.Day, grid("2026-01-01", "2026-07-01", "2026-03-01", max = DotLimits.MEDIUM).unit)
    }

    @Test
    fun chosenUnitIsKeptWhenItFits() {
        val months = grid("2026-01-01", "2027-01-01", "2026-03-15", DotOptions(unit = DotUnit.Month))
        assertEquals(DotGridUnit.Month, months.unit)
        assertEquals(12, months.total)
        assertEquals(2, months.elapsed)
    }

    @Test
    fun fallsBackToYearsAndCaps() {
        val grid = grid("1900-01-01", "2200-01-01", "2026-01-01")
        assertEquals(DotGridUnit.Year, grid.unit)
        assertEquals(DotLimits.SMALL, grid.total)
        assertEquals(DotLimits.SMALL, grid.elapsed)
    }

    @Test
    fun fillPastOrFuture() {
        val past = grid("2026-10-01", "2026-10-11", "2026-10-04")
        assertTrue(past.isFilled(0))
        assertFalse(past.isFilled(5))
        val future = grid("2026-10-01", "2026-10-11", "2026-10-04", DotOptions(fillPast = false))
        assertFalse(future.isFilled(0))
        assertTrue(future.isFilled(5))
    }

    @Test
    fun emptyRange() {
        assertEquals(0, grid("2026-10-10", "2026-10-01", "2026-10-05").total)
    }
}
