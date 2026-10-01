package com.drahanov.purrgets

import com.drahanov.purrgets.domain.calc.Cameo
import com.drahanov.purrgets.domain.calc.CameoPose
import com.drahanov.purrgets.domain.calc.CameoReason
import com.drahanov.purrgets.domain.calc.Cat
import com.drahanov.purrgets.domain.engine.TrackerEngine
import com.drahanov.purrgets.domain.engine.TrackerState
import com.drahanov.purrgets.domain.model.Appearance
import com.drahanov.purrgets.domain.model.CountdownStyle
import com.drahanov.purrgets.domain.model.DotOptions
import com.drahanov.purrgets.domain.model.DotShape
import com.drahanov.purrgets.domain.model.Moment
import com.drahanov.purrgets.domain.model.ProgressRange
import com.drahanov.purrgets.domain.model.ProgressStyle
import com.drahanov.purrgets.domain.model.Theme
import com.drahanov.purrgets.domain.model.TimeSinceStyle
import com.drahanov.purrgets.domain.model.Tracker
import com.drahanov.purrgets.domain.model.TrackerKind
import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.LocalTime
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toInstant
import kotlin.time.Duration.Companion.hours

class PreviewState(val name: String, val state: TrackerState)

/**
 * Fixed sample trackers in every style, at a fixed moment, for SwiftUI previews,
 * snapshot tests and the widget gallery. Always gives the same pictures.
 */
object PreviewStates {
    private val zone = TimeZone.of("Europe/Kyiv")
    private val now = LocalDateTime(2026, 10, 1, 12, 0).toInstant(zone)
    private val created = LocalDateTime(2026, 8, 1, 9, 0).toInstant(zone)
    private val engine = TrackerEngine()

    private val trip = Moment(LocalDate(2026, 12, 15))
    private val quit = Moment(LocalDate(2025, 8, 1))

    private fun tracker(name: String, title: String, kind: TrackerKind, theme: Theme) =
        name to Tracker(name, title, kind, Appearance(theme), created, created)

    private val trackers = listOf(
        tracker("countdown-number", "Lisbon trip", TrackerKind.Countdown(trip, CountdownStyle.Number), Theme.Tangerine),
        tracker("countdown-ring", "Lisbon trip", TrackerKind.Countdown(trip, CountdownStyle.Ring), Theme.Marigold),
        tracker("countdown-dots", "Lisbon trip", TrackerKind.Countdown(trip, CountdownStyle.Dots()), Theme.Sand),
        tracker("countdown-paws", "Lisbon trip", TrackerKind.Countdown(trip, CountdownStyle.Dots(DotOptions(shape = DotShape.Paw))), Theme.Paper),
        tracker("countdown-bar", "Lisbon trip", TrackerKind.Countdown(trip, CountdownStyle.Linear(cat = false)), Theme.Marigold),
        tracker("countdown-long-cat", "Lisbon trip", TrackerKind.Countdown(trip, CountdownStyle.Linear(cat = true)), Theme.Tangerine),
        tracker(
            "countdown-today",
            "Flight",
            TrackerKind.Countdown(Moment(LocalDate(2026, 10, 1), LocalTime(18, 30), zone), CountdownStyle.Number),
            Theme.Sand,
        ),
        tracker("since-number", "No sugar", TrackerKind.TimeSince(quit, TimeSinceStyle.Number), Theme.Sand),
        tracker("since-ring", "No sugar", TrackerKind.TimeSince(quit, TimeSinceStyle.Ring), Theme.Tangerine),
        tracker("since-dots", "No sugar", TrackerKind.TimeSince(quit, TimeSinceStyle.Dots(DotOptions(shape = DotShape.Square))), Theme.Marigold),
        tracker("since-fat-cat", "No sugar", TrackerKind.TimeSince(quit, TimeSinceStyle.FatCat), Theme.Sand),
        tracker("year-number", "2026", TrackerKind.Progress(ProgressRange.Year, ProgressStyle.Number), Theme.Paper),
        tracker("year-ring", "2026", TrackerKind.Progress(ProgressRange.Year, ProgressStyle.Ring), Theme.Tangerine),
        tracker("year-dots", "2026", TrackerKind.Progress(ProgressRange.Year, ProgressStyle.Dots()), Theme.Sand),
        tracker("month-long-cat", "October", TrackerKind.Progress(ProgressRange.Month, ProgressStyle.Linear(cat = true)), Theme.Marigold),
    )

    fun all(maxDots: Int): List<PreviewState> {
        val plain = trackers.map { (name, tracker) ->
            PreviewState(name, engine.state(tracker, now, zone, maxDots).copy(cameo = null))
        }
        val base = plain.first { it.name == "countdown-number" }.state
        val cameos = CameoPose.entries.mapIndexed { index, pose ->
            val cat = if (index % 2 == 0) Cat.Long else Cat.Fat
            PreviewState(
                "cameo-${pose.name.lowercase()}",
                base.copy(cameo = Cameo(cat, pose, CameoReason.Random, now, now + 2.hours)),
            )
        }
        return plain + cameos
    }

    fun named(name: String, maxDots: Int): TrackerState = all(maxDots).first { it.name == name }.state
}
