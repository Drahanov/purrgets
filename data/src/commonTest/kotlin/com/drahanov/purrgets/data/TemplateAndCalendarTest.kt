package com.drahanov.purrgets.data

import com.drahanov.purrgets.data.calendar.eventMoment
import com.drahanov.purrgets.domain.model.Moment
import com.drahanov.purrgets.domain.model.TrackerKind
import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalTime
import kotlinx.datetime.TimeZone
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.time.Instant

class TemplateAndCalendarTest {
    private val library = TemplateLibrary()

    private fun countdownDate(today: LocalDate, id: String) =
        (library.templates(today).single { it.id == id }.draft.kind as TrackerKind.Countdown).target.date

    @Test
    fun eightTemplatesWithUniqueIds() {
        val templates = library.templates(LocalDate(2026, 10, 1))
        assertEquals(8, templates.size)
        assertEquals(8, templates.map { it.id }.toSet().size)
    }

    @Test
    fun yearlyDatesPointToTheNextOne() {
        assertEquals(LocalDate(2026, 12, 25), countdownDate(LocalDate(2026, 10, 1), "christmas"))
        assertEquals(LocalDate(2026, 12, 25), countdownDate(LocalDate(2026, 12, 25), "christmas")) // today counts
        assertEquals(LocalDate(2027, 12, 25), countdownDate(LocalDate(2026, 12, 26), "christmas"))
        assertEquals(LocalDate(2027, 1, 1), countdownDate(LocalDate(2026, 10, 1), "new-year"))
    }

    @Test
    fun daysSinceStartsToday() {
        val today = LocalDate(2026, 10, 1)
        val kind = library.templates(today).single { it.id == "days-since" }.draft.kind as TrackerKind.TimeSince
        assertEquals(Moment(today), kind.start)
    }

    private val kyiv = TimeZone.of("Europe/Kyiv")
    private val newYork = TimeZone.of("America/New_York")

    @Test
    fun allDayEventIsAFloatingDate() {
        val start = Instant.parse("2026-12-14T22:00:00Z") // midnight 15 Dec in Kyiv
        assertEquals(Moment(LocalDate(2026, 12, 15)), eventMoment(start, isAllDay = true, eventZoneId = null, deviceZone = kyiv))
    }

    @Test
    fun timedEventKeepsItsZone() {
        val start = Instant.parse("2026-12-15T12:30:00Z")
        assertEquals(
            Moment(LocalDate(2026, 12, 15), LocalTime(14, 30), kyiv),
            eventMoment(start, isAllDay = false, eventZoneId = "Europe/Kyiv", deviceZone = newYork),
        )
    }

    @Test
    fun floatingTimedEventUsesDeviceTime() {
        val start = Instant.parse("2026-12-15T14:00:00Z")
        assertEquals(
            Moment(LocalDate(2026, 12, 15), LocalTime(9, 0)),
            eventMoment(start, isAllDay = false, eventZoneId = null, deviceZone = newYork),
        )
    }
}
