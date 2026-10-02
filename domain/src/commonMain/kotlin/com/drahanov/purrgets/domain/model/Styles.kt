package com.drahanov.purrgets.domain.model

sealed interface CountdownStyle {
    data object Number : CountdownStyle
    data object Ring : CountdownStyle
    data class Dots(val options: DotOptions = DotOptions()) : CountdownStyle
    data class Linear(val cat: Boolean) : CountdownStyle
}

sealed interface TimeSinceStyle {
    data object Number : TimeSinceStyle
    data object Ring : TimeSinceStyle
    data class Dots(val options: DotOptions = DotOptions()) : TimeSinceStyle
}

sealed interface ProgressStyle {
    data object Number : ProgressStyle
    data object Ring : ProgressStyle
    data class Dots(val options: DotOptions = DotOptions()) : ProgressStyle
    data class Linear(val cat: Boolean) : ProgressStyle
}

data class DotOptions(
    val unit: DotUnit = DotUnit.Auto,
    val shape: DotShape = DotShape.Circle,
    val fillPast: Boolean = true,
)

enum class DotUnit { Auto, Day, Week, Month }

enum class DotShape { Circle, Square, Paw }
