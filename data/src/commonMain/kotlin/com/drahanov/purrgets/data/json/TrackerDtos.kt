package com.drahanov.purrgets.data.json

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * The trackers.json format. Kept apart from the domain model so the file can change
 * (with a migration) without touching the domain, and the domain can change without
 * breaking files already on users' devices.
 */
@Serializable
data class TrackerDto(
    val id: String,
    val title: String,
    val kind: KindDto,
    val appearance: AppearanceDto = AppearanceDto(),
    /** ISO-8601, e.g. 2026-10-01T12:00:00Z */
    val createdAt: String,
    val updatedAt: String,
)

@Serializable
sealed interface KindDto {
    @Serializable
    @SerialName("countdown")
    data class Countdown(val target: MomentDto, val style: StyleDto) : KindDto

    @Serializable
    @SerialName("timeSince")
    data class TimeSince(val start: MomentDto, val style: StyleDto) : KindDto

    @Serializable
    @SerialName("progress")
    data class Progress(val range: RangeDto, val style: StyleDto) : KindDto
}

/** date "2026-12-15", time "14:30", zone "Europe/Kyiv". */
@Serializable
data class MomentDto(val date: String, val time: String? = null, val zone: String? = null)

@Serializable
sealed interface RangeDto {
    @Serializable @SerialName("year") data object Year : RangeDto
    @Serializable @SerialName("month") data object Month : RangeDto
    @Serializable @SerialName("week") data object Week : RangeDto
    @Serializable @SerialName("custom") data class Custom(val start: MomentDto, val end: MomentDto) : RangeDto
}

/** One list of styles for all types. The mapper checks which ones a type allows. */
@Serializable
sealed interface StyleDto {
    @Serializable @SerialName("number") data object Number : StyleDto
    @Serializable @SerialName("ring") data object Ring : StyleDto
    @Serializable @SerialName("dots") data class Dots(val dots: DotsDto = DotsDto()) : StyleDto
    @Serializable @SerialName("linear") data class Linear(val cat: Boolean = false) : StyleDto
    /** Removed style; older files may still have it. Read as Number, never written. */
    @Serializable @SerialName("fatCat") data object FatCat : StyleDto
}

@Serializable
data class DotsDto(
    val unit: DotUnitDto = DotUnitDto.Auto,
    val shape: DotShapeDto = DotShapeDto.Circle,
    val fillPast: Boolean = true,
)

@Serializable
enum class DotUnitDto {
    @SerialName("auto") Auto,
    @SerialName("day") Day,
    @SerialName("week") Week,
    @SerialName("month") Month,
}

@Serializable
enum class DotShapeDto {
    @SerialName("circle") Circle,
    @SerialName("square") Square,
    @SerialName("paw") Paw,
}

@Serializable
data class AppearanceDto(val theme: ThemeDto = ThemeDto.Tangerine, val cameos: Boolean = true)

@Serializable
enum class ThemeDto {
    @SerialName("tangerine") Tangerine,
    @SerialName("marigold") Marigold,
    @SerialName("sand") Sand,
    @SerialName("paper") Paper,
}
