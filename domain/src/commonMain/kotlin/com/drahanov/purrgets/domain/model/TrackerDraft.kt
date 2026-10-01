package com.drahanov.purrgets.domain.model

/** A tracker not saved yet: what the editor starts from (blank, a template or a calendar event). */
data class TrackerDraft(
    val title: String,
    val kind: TrackerKind,
    val appearance: Appearance = Appearance.Default,
)

data class Template(val id: String, val draft: TrackerDraft)

data class CalendarEvent(
    val id: String,
    val title: String,
    val calendar: String,
    val moment: Moment,
)
