package com.drahanov.purrgets.data

import com.drahanov.purrgets.data.json.Migration
import com.drahanov.purrgets.data.json.ReadResult
import com.drahanov.purrgets.data.json.TrackerFile
import com.drahanov.purrgets.domain.model.Tracker
import com.drahanov.purrgets.domain.model.TrackerId
import com.drahanov.purrgets.domain.repository.TrackerRepository
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.IO
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.io.buffered
import kotlinx.io.files.FileSystem
import kotlinx.io.files.Path
import kotlinx.io.files.SystemFileSystem
import kotlinx.io.readString
import kotlinx.io.writeString

/**
 * Stores all trackers in one JSON file in [directory] (the App Group folder on Apple platforms).
 *
 * - Writes go to a temp file that is then renamed, so readers (the widget) see either the
 *   old file or the new one, never half of it.
 * - Reading never changes the file. A broken file is only moved aside to
 *   trackers.broken.json by the next save, so the user's data isn't lost silently.
 */
class JsonTrackerRepository internal constructor(
    directory: String,
    private val fileSystem: FileSystem,
    private val format: TrackerFile,
    private val io: CoroutineDispatcher,
) : TrackerRepository {

    constructor(directory: String) : this(
        directory,
        SystemFileSystem,
        TrackerFile(TrackerFile.MIGRATIONS, TrackerFile.CURRENT_VERSION),
        Dispatchers.IO,
    )

    internal constructor(directory: String, fileSystem: FileSystem, migrations: List<Migration>, version: Int) :
        this(directory, fileSystem, TrackerFile(migrations, version), Dispatchers.IO)

    private val folder = Path(directory)
    private val file = Path(directory, FILE_NAME)
    private val temp = Path(directory, "$FILE_NAME.tmp")
    private val broken = Path(directory, BROKEN_FILE_NAME)
    private val writeLock = Mutex()

    override suspend fun all(): List<Tracker> = withContext(io) { read().trackers }

    override suspend fun get(id: TrackerId): Tracker? = all().firstOrNull { it.id == id }

    override suspend fun save(tracker: Tracker) = update { trackers ->
        val index = trackers.indexOfFirst { it.id == tracker.id }
        if (index >= 0) trackers.toMutableList().apply { set(index, tracker) } else trackers + tracker
    }

    override suspend fun delete(id: TrackerId) = update { trackers -> trackers.filterNot { it.id == id } }

    private suspend fun update(change: (List<Tracker>) -> List<Tracker>) = writeLock.withLock {
        withContext(io) {
            val current = read()
            if (current.isBroken) fileSystem.atomicMove(file, broken)
            write(change(current.trackers))
        }
    }

    private fun read(): ReadResult {
        if (!fileSystem.exists(file)) return ReadResult(emptyList(), isBroken = false)
        val text = fileSystem.source(file).buffered().use { it.readString() }
        return format.decode(text)
    }

    private fun write(trackers: List<Tracker>) {
        fileSystem.createDirectories(folder)
        fileSystem.sink(temp).buffered().use { it.writeString(format.encode(trackers)) }
        fileSystem.atomicMove(temp, file)
    }

    companion object {
        const val FILE_NAME = "trackers.json"
        const val BROKEN_FILE_NAME = "trackers.broken.json"
    }
}
