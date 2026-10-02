package com.drahanov.purrgets.domain.calc

import com.drahanov.purrgets.domain.model.TrackerId
import kotlin.time.Duration.Companion.minutes
import kotlin.time.Instant

/** The lying cat belongs to Progress cards, so cameos use the other poses. */
enum class CameoPose {
    /** Hanging upside down from the top edge, head and paws showing. */
    Paws,
    /** The tail rises in from the bottom-right corner. */
    Tail,
    /** Dangling from the top edge by its front paws. */
    Hang,
    /** Strolling in from the right edge. */
    Walk,
    /** Standing tall, half behind the right edge. */
    Tall,
}

/** Where the cat looks. */
enum class CameoLook { Ahead, Left, Right }

enum class CameoReason { Milestone, Random }

/** A cat visiting the widget between [from] and [until]. */
data class Cameo(
    val pose: CameoPose,
    val look: CameoLook,
    /** Napping, eyes shut. */
    val eyesClosed: Boolean,
    val reason: CameoReason,
    val from: Instant,
    val until: Instant,
) {
    fun isVisibleAt(at: Instant) = at >= from && at < until
}

/**
 * A cat is always around and moves every [SLOT]: a new pose, a new glance, now and then a nap.
 * [SLOT] is as often as Apple lets widget frames change ("at least about 5 minutes apart").
 * On milestone days every other slot is Paws. Seeded by tracker and slot, so a reload never
 * changes it and two widgets don't move in step.
 */
object CameoSchedule {
    val SLOT = 5.minutes

    /** One slot in [NAP_ODDS] is a nap. */
    const val NAP_ODDS = 8

    /** The start of the slot [at] falls in. Slots line up with the clock: :00, :05, :10… */
    fun slotStart(at: Instant): Instant {
        val slot = SLOT.inWholeSeconds
        return Instant.fromEpochSeconds(at.epochSeconds.floorDiv(slot) * slot)
    }

    fun cameo(trackerId: TrackerId, at: Instant, isMilestoneDay: Boolean): Cameo {
        val from = slotStart(at)
        val slot = from.epochSeconds / SLOT.inWholeSeconds
        val seed = Seed(fnv1a("$trackerId|$slot"))
        val roll = seed.next(CameoPose.entries.size)
        val pose = if (isMilestoneDay && slot % 2 == 0L) CameoPose.Paws else pose(trackerId, slot, roll)
        return Cameo(
            pose = pose,
            look = CameoLook.entries[seed.next(CameoLook.entries.size)],
            eyesClosed = seed.next(NAP_ODDS) == 0,
            reason = if (isMilestoneDay) CameoReason.Milestone else CameoReason.Random,
            from = from,
            until = from + SLOT,
        )
    }

    /** A random pose that hardly ever repeats the slot before, so the cat keeps moving. */
    private fun pose(trackerId: TrackerId, slot: Long, roll: Int): CameoPose {
        val previous = Seed(fnv1a("$trackerId|${slot - 1}")).next(CameoPose.entries.size)
        val index = if (roll == previous) (roll + 1) % CameoPose.entries.size else roll
        return CameoPose.entries[index]
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
