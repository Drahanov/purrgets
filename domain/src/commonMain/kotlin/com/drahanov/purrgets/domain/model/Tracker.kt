package com.drahanov.purrgets.domain.model

import kotlin.time.Instant
import kotlin.uuid.Uuid

typealias TrackerId = String

fun randomTrackerId(): TrackerId = Uuid.random().toString()

data class Tracker(
    val id: TrackerId,
    val title: String,
    val kind: TrackerKind,
    val appearance: Appearance = Appearance.Default,
    val createdAt: Instant,
    val updatedAt: Instant,
)

/** The tracker type with its dates and its style. Each type only accepts its own styles. */
sealed interface TrackerKind {
    data class Countdown(val target: Moment, val style: CountdownStyle) : TrackerKind
    data class TimeSince(val start: Moment, val style: TimeSinceStyle) : TrackerKind
    data class Progress(val range: ProgressRange, val style: ProgressStyle) : TrackerKind
}

sealed interface ProgressRange {
    data object Year : ProgressRange
    data object Month : ProgressRange
    data object Week : ProgressRange

    /** [end] is inclusive: a date-only end lasts until the end of that day. */
    data class Custom(val start: Moment, val end: Moment) : ProgressRange
}

/** [cameos]: cats may visit the card now and then (only Number cards have room for them). */
data class Appearance(val theme: Theme = Theme.Tangerine, val cameos: Boolean = true) {
    companion object {
        val Default = Appearance()
    }
}

enum class Theme { Tangerine, Marigold, Sand, Paper }
