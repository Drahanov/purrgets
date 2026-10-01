package com.drahanov.purrgets.domain.usecase

import com.drahanov.purrgets.domain.TimeZoneProvider
import com.drahanov.purrgets.domain.engine.TrackerEngine
import com.drahanov.purrgets.domain.engine.TrackerState
import com.drahanov.purrgets.domain.model.Appearance
import com.drahanov.purrgets.domain.model.ProgressRange
import com.drahanov.purrgets.domain.model.Tracker
import com.drahanov.purrgets.domain.model.TrackerDraft
import com.drahanov.purrgets.domain.model.TrackerId
import com.drahanov.purrgets.domain.model.TrackerKind
import com.drahanov.purrgets.domain.repository.TrackerRepository
import kotlin.time.Clock

class ListTrackers(private val repository: TrackerRepository) {
    suspend operator fun invoke(): List<Tracker> = repository.all().sortedBy { it.createdAt }
}

class DeleteTracker(private val repository: TrackerRepository) {
    suspend operator fun invoke(id: TrackerId) = repository.delete(id)
}

enum class ValidationError { EmptyTitle, RangeEndsBeforeStart }

sealed interface SaveResult {
    data class Saved(val tracker: Tracker) : SaveResult
    data class Invalid(val errors: List<ValidationError>) : SaveResult
}

/** Creates a tracker, or updates it if [id] already exists (keeping its creation time). */
class SaveTracker(
    private val repository: TrackerRepository,
    private val clock: Clock,
    private val zones: TimeZoneProvider,
) {
    suspend operator fun invoke(
        id: TrackerId,
        title: String,
        kind: TrackerKind,
        appearance: Appearance = Appearance.Default,
    ): SaveResult {
        val errors = validate(title, kind)
        if (errors.isNotEmpty()) return SaveResult.Invalid(errors)

        val now = clock.now()
        val tracker = Tracker(
            id = id,
            title = title.trim(),
            kind = kind,
            appearance = appearance,
            createdAt = repository.get(id)?.createdAt ?: now,
            updatedAt = now,
        )
        repository.save(tracker)
        return SaveResult.Saved(tracker)
    }

    suspend operator fun invoke(id: TrackerId, draft: TrackerDraft): SaveResult =
        invoke(id, draft.title, draft.kind, draft.appearance)

    private fun validate(title: String, kind: TrackerKind): List<ValidationError> = buildList {
        if (title.isBlank()) add(ValidationError.EmptyTitle)
        val range = (kind as? TrackerKind.Progress)?.range as? ProgressRange.Custom
        if (range != null) {
            val zone = zones.current()
            if (range.end.localDate(zone) < range.start.localDate(zone) ||
                (range.end.time != null && range.end.toInstant(zone) <= range.start.toInstant(zone))
            ) add(ValidationError.RangeEndsBeforeStart)
        }
    }
}

/** The state of a tracker right now: for home cards and the editor's live preview. */
class RenderTracker(
    private val engine: TrackerEngine,
    private val clock: Clock,
    private val zones: TimeZoneProvider,
) {
    operator fun invoke(tracker: Tracker, maxDots: Int): TrackerState =
        engine.state(tracker, clock.now(), zones.current(), maxDots)
}
