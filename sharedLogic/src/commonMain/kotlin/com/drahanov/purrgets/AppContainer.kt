package com.drahanov.purrgets

import com.drahanov.purrgets.data.JsonTrackerRepository
import com.drahanov.purrgets.data.TemplateLibrary
import com.drahanov.purrgets.domain.TimeZoneProvider
import com.drahanov.purrgets.domain.engine.TimelinePlanner
import com.drahanov.purrgets.domain.engine.TrackerEngine
import com.drahanov.purrgets.domain.repository.CalendarSource
import com.drahanov.purrgets.domain.usecase.BuildWidgetTimeline
import com.drahanov.purrgets.domain.usecase.DeleteTracker
import com.drahanov.purrgets.domain.usecase.DraftFromEvent
import com.drahanov.purrgets.domain.usecase.ListTemplates
import com.drahanov.purrgets.domain.usecase.ListTrackers
import com.drahanov.purrgets.domain.usecase.LoadCalendarEvents
import com.drahanov.purrgets.domain.usecase.RenderTracker
import com.drahanov.purrgets.domain.usecase.SaveTracker
import kotlin.time.Clock

/**
 * Composition root: builds and connects everything once per process.
 * The app and the widget each create their own, pointing at the same [storageDirectory].
 */
class AppContainer(
    storageDirectory: String,
    calendar: (() -> CalendarSource)? = null,
    clock: Clock = Clock.System,
    zones: TimeZoneProvider = TimeZoneProvider.System,
) {
    private val repository = JsonTrackerRepository(storageDirectory)
    private val engine = TrackerEngine()

    val listTrackers = ListTrackers(repository)
    val saveTracker = SaveTracker(repository, clock, zones)
    val deleteTracker = DeleteTracker(repository)
    val renderTracker = RenderTracker(engine, clock, zones)
    val buildWidgetTimeline = BuildWidgetTimeline(repository, TimelinePlanner(engine), engine, clock, zones)
    val listTemplates = ListTemplates(TemplateLibrary(), clock, zones)
    val draftFromEvent = DraftFromEvent()

    /** Null where there is no calendar. Created on first use, so the widget never touches EventKit. */
    val loadCalendarEvents: LoadCalendarEvents? by lazy { calendar?.let { LoadCalendarEvents(it(), clock) } }
}
