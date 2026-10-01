package com.drahanov.purrgets.domain.repository

import com.drahanov.purrgets.domain.model.Tracker
import com.drahanov.purrgets.domain.model.TrackerId

/** Implemented in the data layer. The domain only knows this interface. */
interface TrackerRepository {
    suspend fun all(): List<Tracker>
    suspend fun get(id: TrackerId): Tracker?
    suspend fun save(tracker: Tracker)
    suspend fun delete(id: TrackerId)
}
