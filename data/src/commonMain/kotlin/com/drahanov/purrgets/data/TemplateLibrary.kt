package com.drahanov.purrgets.data

import com.drahanov.purrgets.domain.model.Appearance
import com.drahanov.purrgets.domain.model.CountdownStyle
import com.drahanov.purrgets.domain.model.DotOptions
import com.drahanov.purrgets.domain.model.DotShape
import com.drahanov.purrgets.domain.model.Moment
import com.drahanov.purrgets.domain.model.ProgressRange
import com.drahanov.purrgets.domain.model.ProgressStyle
import com.drahanov.purrgets.domain.model.Template
import com.drahanov.purrgets.domain.model.Theme
import com.drahanov.purrgets.domain.model.TimeSinceStyle
import com.drahanov.purrgets.domain.model.TrackerDraft
import com.drahanov.purrgets.domain.model.TrackerKind
import com.drahanov.purrgets.domain.repository.TemplateSource
import kotlinx.datetime.LocalDate
import kotlinx.datetime.Month

/** The built-in templates. Yearly dates point to their next occurrence (today counts). */
class TemplateLibrary : TemplateSource {

    override fun templates(today: LocalDate): List<Template> = listOf(
        countdown("new-year", "New Year", next(Month.JANUARY, 1, today), CountdownStyle.Number, Theme.Tangerine),
        countdown("christmas", "Christmas", next(Month.DECEMBER, 25, today), CountdownStyle.Dots(DotOptions(shape = DotShape.Paw)), Theme.Marigold),
        countdown("valentines", "Valentine's Day", next(Month.FEBRUARY, 14, today), CountdownStyle.Ring, Theme.Sand),
        countdown("summer", "Summer", next(Month.JUNE, 1, today), CountdownStyle.Linear(cat = true), Theme.Marigold),
        progress("year", "This year", ProgressRange.Year, ProgressStyle.Linear(cat = true), Theme.Tangerine),
        progress("month", "This month", ProgressRange.Month, ProgressStyle.Dots(), Theme.Sand),
        progress("week", "This week", ProgressRange.Week, ProgressStyle.Ring, Theme.Paper),
        Template(
            id = "days-since",
            draft = TrackerDraft("Days since", TrackerKind.TimeSince(Moment(today), TimeSinceStyle.Number), Appearance(Theme.Sand)),
        ),
    )

    private fun countdown(id: String, title: String, date: LocalDate, style: CountdownStyle, theme: Theme) =
        Template(id, TrackerDraft(title, TrackerKind.Countdown(Moment(date), style), Appearance(theme)))

    private fun progress(id: String, title: String, range: ProgressRange, style: ProgressStyle, theme: Theme) =
        Template(id, TrackerDraft(title, TrackerKind.Progress(range, style), Appearance(theme)))

    private fun next(month: Month, day: Int, today: LocalDate): LocalDate {
        val thisYear = LocalDate(today.year, month, day)
        return if (thisYear >= today) thisYear else LocalDate(today.year + 1, month, day)
    }
}
