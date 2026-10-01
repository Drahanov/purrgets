package com.drahanov.purrgets.domain

import kotlinx.datetime.TimeZone

/** The device's current time zone. Injected so tests can pretend to travel. */
fun interface TimeZoneProvider {
    fun current(): TimeZone

    companion object {
        val System = TimeZoneProvider { TimeZone.currentSystemDefault() }
    }
}
