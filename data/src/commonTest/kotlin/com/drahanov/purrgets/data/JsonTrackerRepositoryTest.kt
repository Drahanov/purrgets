package com.drahanov.purrgets.data

import com.drahanov.purrgets.data.json.Migration
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
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalTime
import kotlinx.datetime.TimeZone
import kotlinx.io.buffered
import kotlinx.io.files.Path
import kotlinx.io.files.SystemFileSystem
import kotlinx.io.files.SystemTemporaryDirectory
import kotlinx.io.readString
import kotlinx.io.writeString
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlin.random.Random
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.time.Instant

class JsonTrackerRepositoryTest {
    private val fs = SystemFileSystem
    private val dir = Path(SystemTemporaryDirectory, "purrgets-test-${Random.nextLong().toULong()}")
    private val file = Path(dir, JsonTrackerRepository.FILE_NAME)
    private val repository = JsonTrackerRepository(dir.toString())

    private val created = Instant.parse("2026-10-01T09:00:00Z")
    private fun tracker(id: String, kind: TrackerKind, theme: Theme = Theme.Tangerine) =
        Tracker(id, "Title $id", kind, Appearance(theme), created, created)

    private val all = listOf(
        tracker("1", TrackerKind.Countdown(Moment(LocalDate(2026, 12, 15)), CountdownStyle.Dots(DotOptions(DotUnit.Week, DotShape.Paw, false)))),
        tracker("2", TrackerKind.Countdown(Moment(LocalDate(2026, 12, 15), LocalTime(14, 30), TimeZone.of("Europe/Kyiv")), CountdownStyle.Linear(cat = true)), Theme.Sand),
        tracker("3", TrackerKind.TimeSince(Moment(LocalDate(2025, 8, 1), LocalTime(9, 15)), TimeSinceStyle.Ring), Theme.Marigold),
        tracker("4", TrackerKind.Progress(ProgressRange.Custom(Moment(LocalDate(2026, 1, 1)), Moment(LocalDate(2026, 6, 30))), ProgressStyle.Ring), Theme.Paper),
        tracker("5", TrackerKind.Progress(ProgressRange.Week, ProgressStyle.Number)),
    )

    @AfterTest
    fun cleanUp() {
        if (fs.exists(dir)) fs.list(dir).forEach(fs::delete)
        fs.delete(dir, mustExist = false)
    }

    private fun writeRaw(text: String) {
        fs.createDirectories(dir)
        fs.sink(file).buffered().use { it.writeString(text) }
    }

    private fun readRaw(path: Path = file) = fs.source(path).buffered().use { it.readString() }

    @Test
    fun emptyWhenNoFile() = runTest {
        assertEquals(emptyList(), repository.all())
    }

    @Test
    fun everyKindAndStyleSurvivesARoundTrip() = runTest {
        all.forEach { repository.save(it) }
        assertEquals(all, JsonTrackerRepository(dir.toString()).all())
    }

    @Test
    fun saveReplacesInPlaceAndDeleteRemoves() = runTest {
        all.forEach { repository.save(it) }
        val renamed = all[1].copy(title = "Renamed")
        repository.save(renamed)
        repository.delete("4")
        assertEquals(listOf("1", "2", "3", "5"), repository.all().map { it.id })
        assertEquals(renamed, repository.get("2"))
        assertNull(repository.get("4"))
    }

    @Test
    fun noTempFileLeftBehind() = runTest {
        repository.save(all[0])
        assertEquals(listOf(file.name), fs.list(dir).map { it.name })
    }

    @Test
    fun fileLooksLikeTheReadme() = runTest {
        repository.save(all[0])
        val text = readRaw()
        assertTrue("\"schemaVersion\": 1" in text, text)
        assertTrue("\"type\": \"countdown\"" in text, text)
        assertTrue("\"shape\": \"paw\"" in text, text)
    }

    @Test
    fun brokenFileReadsEmptyAndIsKeptAsBackupOnSave() = runTest {
        writeRaw("{ not json")
        assertEquals(emptyList(), repository.all())
        assertEquals("{ not json", readRaw()) // reading never touches it

        repository.save(all[0])
        assertEquals("{ not json", readRaw(Path(dir, JsonTrackerRepository.BROKEN_FILE_NAME)))
        assertEquals(listOf(all[0]), repository.all())
    }

    @Test
    fun oneBadTrackerDoesNotHideTheOthers() = runTest {
        repository.save(all[0])
        val text = readRaw().replaceFirst("\"trackers\": [", "\"trackers\": [ { \"id\": \"x\", \"kind\": { \"type\": \"rocket\" } },")
        writeRaw(text)
        assertEquals(listOf(all[0]), repository.all())
    }

    @Test
    fun unknownValuesFallBackToDefaults() = runTest {
        repository.save(all[0])
        writeRaw(readRaw().replace("\"paw\"", "\"star\"").replace("\"tangerine\"", "\"neon\"") .replace("\"title\"", "\"newField\": 1, \"title\""))
        val tracker = repository.all().single()
        val style = (tracker.kind as TrackerKind.Countdown).style as CountdownStyle.Dots
        assertEquals(DotShape.Circle, style.options.shape)
        assertEquals(Theme.Tangerine, tracker.appearance.theme)
    }

    @Test
    fun removedFatCatStyleBecomesNumber() = runTest {
        repository.save(all[2])
        writeRaw(readRaw().replace("\"type\": \"ring\"", "\"type\": \"fatCat\""))
        assertEquals(TimeSinceStyle.Number, (repository.all().single().kind as TrackerKind.TimeSince).style)
    }

    @Test
    fun styleNotAllowedForTypeBecomesNumber() = runTest {
        repository.save(all[0])
        writeRaw(readRaw().replace(Regex("\"style\": \\{[^}]*\\{[^}]*\\}[^}]*\\}"), "\"style\": { \"type\": \"fatCat\" }"))
        assertEquals(CountdownStyle.Number, (repository.all().single().kind as TrackerKind.Countdown).style)
    }

    @Test
    fun oldFilesAreMigrated() = runTest {
        // Pretend version 1 named the field "name" and version 2 renamed it to "title".
        val renameTitle = Migration(from = 1) { root ->
            val trackers = root.getValue("trackers").jsonArray.map { entry ->
                val obj = entry.jsonObject
                JsonObject(obj - "name" + ("title" to obj.getValue("name")))
            }
            JsonObject(root + ("trackers" to buildJsonArray { trackers.forEach { add(it) } }))
        }
        val v2 = JsonTrackerRepository(dir.toString(), fs, listOf(renameTitle), version = 2)
        repository.save(all[0])
        writeRaw(readRaw().replace("\"title\"", "\"name\""))

        assertEquals(listOf(all[0]), v2.all())
        v2.save(all[1])
        assertTrue("\"schemaVersion\": 2" in readRaw())
        assertFalse("\"name\"" in readRaw())
    }

    @Test
    fun missingTrackersListIsEmpty() = runTest {
        writeRaw(buildJsonObject { put("schemaVersion", JsonPrimitive(1)) }.toString())
        assertEquals(emptyList(), repository.all())
    }
}
