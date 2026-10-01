package com.drahanov.purrgets.data.json

import com.drahanov.purrgets.domain.model.Appearance
import com.drahanov.purrgets.domain.model.CountdownStyle
import com.drahanov.purrgets.domain.model.DotOptions
import com.drahanov.purrgets.domain.model.DotShape
import com.drahanov.purrgets.domain.model.DotUnit
import com.drahanov.purrgets.domain.model.Moment
import com.drahanov.purrgets.domain.model.ProgressRange
import com.drahanov.purrgets.domain.model.ProgressStyle
import com.drahanov.purrgets.domain.model.Theme
import com.drahanov.purrgets.domain.model.TimeSinceStyle
import com.drahanov.purrgets.domain.model.Tracker
import com.drahanov.purrgets.domain.model.TrackerKind
import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalTime
import kotlinx.datetime.TimeZone
import kotlin.time.Instant

/** Domain ⇄ file. A style a type doesn't allow falls back to Number instead of failing. */
internal object TrackerMapper {

    fun toDto(tracker: Tracker) = TrackerDto(
        id = tracker.id,
        title = tracker.title,
        kind = when (val kind = tracker.kind) {
            is TrackerKind.Countdown -> KindDto.Countdown(kind.target.toDto(), kind.style.toDto())
            is TrackerKind.TimeSince -> KindDto.TimeSince(kind.start.toDto(), kind.style.toDto())
            is TrackerKind.Progress -> KindDto.Progress(kind.range.toDto(), kind.style.toDto())
        },
        appearance = AppearanceDto(ThemeDto.valueOf(tracker.appearance.theme.name)),
        createdAt = tracker.createdAt.toString(),
        updatedAt = tracker.updatedAt.toString(),
    )

    fun toDomain(dto: TrackerDto) = Tracker(
        id = dto.id,
        title = dto.title,
        kind = when (val kind = dto.kind) {
            is KindDto.Countdown -> TrackerKind.Countdown(kind.target.toDomain(), kind.style.toCountdownStyle())
            is KindDto.TimeSince -> TrackerKind.TimeSince(kind.start.toDomain(), kind.style.toTimeSinceStyle())
            is KindDto.Progress -> TrackerKind.Progress(kind.range.toDomain(), kind.style.toProgressStyle())
        },
        appearance = Appearance(Theme.valueOf(dto.appearance.theme.name)),
        createdAt = Instant.parse(dto.createdAt),
        updatedAt = Instant.parse(dto.updatedAt),
    )

    private fun Moment.toDto() = MomentDto(date.toString(), time?.toString(), zone?.id)

    private fun MomentDto.toDomain() = Moment(
        date = LocalDate.parse(date),
        time = time?.let(LocalTime::parse),
        zone = zone?.takeIf { time != null }?.let(TimeZone::of),
    )

    private fun ProgressRange.toDto() = when (this) {
        ProgressRange.Year -> RangeDto.Year
        ProgressRange.Month -> RangeDto.Month
        ProgressRange.Week -> RangeDto.Week
        is ProgressRange.Custom -> RangeDto.Custom(start.toDto(), end.toDto())
    }

    private fun RangeDto.toDomain() = when (this) {
        RangeDto.Year -> ProgressRange.Year
        RangeDto.Month -> ProgressRange.Month
        RangeDto.Week -> ProgressRange.Week
        is RangeDto.Custom -> ProgressRange.Custom(start.toDomain(), end.toDomain())
    }

    private fun CountdownStyle.toDto() = when (this) {
        CountdownStyle.Number -> StyleDto.Number
        CountdownStyle.Ring -> StyleDto.Ring
        is CountdownStyle.Dots -> StyleDto.Dots(options.toDto())
        is CountdownStyle.Linear -> StyleDto.Linear(cat)
    }

    private fun TimeSinceStyle.toDto() = when (this) {
        TimeSinceStyle.Number -> StyleDto.Number
        TimeSinceStyle.Ring -> StyleDto.Ring
        is TimeSinceStyle.Dots -> StyleDto.Dots(options.toDto())
        TimeSinceStyle.FatCat -> StyleDto.FatCat
    }

    private fun ProgressStyle.toDto() = when (this) {
        ProgressStyle.Number -> StyleDto.Number
        ProgressStyle.Ring -> StyleDto.Ring
        is ProgressStyle.Dots -> StyleDto.Dots(options.toDto())
        is ProgressStyle.Linear -> StyleDto.Linear(cat)
    }

    private fun StyleDto.toCountdownStyle() = when (this) {
        StyleDto.Ring -> CountdownStyle.Ring
        is StyleDto.Dots -> CountdownStyle.Dots(dots.toDomain())
        is StyleDto.Linear -> CountdownStyle.Linear(cat)
        StyleDto.Number, StyleDto.FatCat -> CountdownStyle.Number
    }

    private fun StyleDto.toTimeSinceStyle() = when (this) {
        StyleDto.Ring -> TimeSinceStyle.Ring
        is StyleDto.Dots -> TimeSinceStyle.Dots(dots.toDomain())
        StyleDto.FatCat -> TimeSinceStyle.FatCat
        StyleDto.Number, is StyleDto.Linear -> TimeSinceStyle.Number
    }

    private fun StyleDto.toProgressStyle() = when (this) {
        StyleDto.Ring -> ProgressStyle.Ring
        is StyleDto.Dots -> ProgressStyle.Dots(dots.toDomain())
        is StyleDto.Linear -> ProgressStyle.Linear(cat)
        StyleDto.Number, StyleDto.FatCat -> ProgressStyle.Number
    }

    private fun DotOptions.toDto() =
        DotsDto(DotUnitDto.valueOf(unit.name), DotShapeDto.valueOf(shape.name), fillPast)

    private fun DotsDto.toDomain() =
        DotOptions(DotUnit.valueOf(unit.name), DotShape.valueOf(shape.name), fillPast)
}
