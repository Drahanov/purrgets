package com.drahanov.purrgets.data.calendar

import com.drahanov.purrgets.domain.TimeZoneProvider
import com.drahanov.purrgets.domain.model.CalendarEvent
import com.drahanov.purrgets.domain.repository.CalendarSource
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.IO
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.datetime.toKotlinInstant
import kotlinx.datetime.toNSDate
import platform.EventKit.EKEvent
import platform.EventKit.EKEventStore
import kotlin.coroutines.resume
import kotlin.time.Instant

/** Reads the device calendar with EventKit. The app's Info.plist needs NSCalendarsFullAccessUsageDescription. */
class EventKitCalendarSource(
    private val zones: TimeZoneProvider = TimeZoneProvider.System,
) : CalendarSource {
    private val store = EKEventStore()

    override suspend fun requestAccess(): Boolean = suspendCancellableCoroutine { continuation ->
        store.requestFullAccessToEventsWithCompletion { granted, _ -> continuation.resume(granted) }
    }

    override suspend fun events(from: Instant, until: Instant): List<CalendarEvent> = withContext(Dispatchers.IO) {
        val zone = zones.current()
        val predicate = store.predicateForEventsWithStartDate(from.toNSDate(), until.toNSDate(), calendars = null)
        store.eventsMatchingPredicate(predicate)
            .filterIsInstance<EKEvent>()
            .mapNotNull { event ->
                val start = event.startDate ?: return@mapNotNull null
                CalendarEvent(
                    id = event.eventIdentifier ?: return@mapNotNull null,
                    title = event.title.orEmpty(),
                    calendar = event.calendar?.title.orEmpty(),
                    moment = eventMoment(start.toKotlinInstant(), event.allDay, event.timeZone?.name, zone),
                )
            }
            .sortedBy { it.moment.toInstant(zone) }
    }
}
