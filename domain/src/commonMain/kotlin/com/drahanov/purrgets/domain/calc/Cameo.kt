package com.drahanov.purrgets.domain.calc

import com.drahanov.purrgets.domain.model.TrackerId
import kotlinx.datetime.DatePeriod
import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.LocalTime
import kotlinx.datetime.TimeZone
import kotlinx.datetime.atStartOfDayIn
import kotlinx.datetime.plus
import kotlinx.datetime.toInstant
import kotlin.time.Duration.Companion.hours
import kotlin.time.Instant

enum class CameoPose {
    /** Head pops up over the bottom edge. */
    Peek,
    /** Front paws hang over the top edge. */
    Paws,
    /** Only the ears stick up from the bottom. */
    Ears,
    /** The tail swishes in from the side. */
    Tail,
    /** Curled up asleep on the top edge. */
    Sleep,
}

enum class CameoReason { Milestone, Random }

/** A cat visiting the widget between [from] and [until]. */
data class Cameo(
    val pose: CameoPose,
    val reason: CameoReason,
    val from: Instant,
    val until: Instant,
) {
    fun isVisibleAt(at: Instant) = at >= from && at < until
}

/**
 * Milestone days: a Peek all day. Other days: about one in [RANDOM_ODDS] gets a random pose
 * pose for 2–4 hours in the morning, afternoon or evening.
 * Seeded by tracker and date, so a reload never changes it.
 */
object CameoSchedule {
    const val RANDOM_ODDS = 3

    private val START_HOURS = listOf(8, 13, 18)
    private const val MIN_HOURS = 2
    private const val MAX_HOURS = 4

    fun cameo(trackerId: TrackerId, date: LocalDate, zone: TimeZone, isMilestoneDay: Boolean): Cameo? {
        val seed = Seed(fnv1a("$trackerId|$date"))
        if (isMilestoneDay) {
            return Cameo(
                pose = CameoPose.Peek,
                reason = CameoReason.Milestone,
                from = date.atStartOfDayIn(zone),
                until = date.plus(DatePeriod(days = 1)).atStartOfDayIn(zone),
            )
        }
        if (seed.next(RANDOM_ODDS) != 0) return null

        val pose = CameoPose.entries[seed.next(CameoPose.entries.size)]
        val hour = START_HOURS[seed.next(START_HOURS.size)]
        val minute = seed.next(60)
        val length = (MIN_HOURS + seed.next(MAX_HOURS - MIN_HOURS + 1)).hours
        val from = LocalDateTime(date, LocalTime(hour, minute)).toInstant(zone)
        return Cameo(pose, CameoReason.Random, from, from + length)
    }

    /** Hands out small numbers from one hash, a few bits at a time. */
    private class Seed(private var bits: ULong) {
        fun next(bound: Int): Int {
            val value = (bits % bound.toULong()).toInt()
            bits = bits shr 8
            return value
        }
    }

    /** FNV-1a: tiny and gives the same result on every platform. */
    private fun fnv1a(text: String): ULong {
        var hash = 0xcbf29ce484222325uL
        for (byte in text.encodeToByteArray()) {
            hash = (hash xor byte.toUByte().toULong()) * 0x100000001b3uL
        }
        return hash
    }
}
