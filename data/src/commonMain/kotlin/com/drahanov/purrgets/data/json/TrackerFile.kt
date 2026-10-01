package com.drahanov.purrgets.data.json

import com.drahanov.purrgets.domain.model.Tracker
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

/** Upgrades the raw file from version [from] to [from] + 1. */
class Migration(val from: Int, val migrate: (JsonObject) -> JsonObject)

internal class ReadResult(val trackers: List<Tracker>, val isBroken: Boolean)

/**
 * trackers.json: `{ "schemaVersion": 1, "trackers": [ … ] }`.
 * Old versions are migrated on read. A tracker that can't be read is skipped, so one bad
 * entry never hides the others.
 */
internal class TrackerFile(
    private val migrations: List<Migration>,
    private val currentVersion: Int,
) {
    private val json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
        explicitNulls = false
        prettyPrint = true
    }

    fun decode(text: String): ReadResult {
        val root = runCatching { json.parseToJsonElement(text).jsonObject }.getOrNull()
            ?: return ReadResult(emptyList(), isBroken = true)
        val migrated = migrate(root)
        val entries = runCatching { (migrated[TRACKERS] ?: JsonArray(emptyList())).jsonArray }.getOrNull()
            ?: return ReadResult(emptyList(), isBroken = true)
        val trackers = entries.mapNotNull { entry ->
            runCatching { TrackerMapper.toDomain(json.decodeFromJsonElement(TrackerDto.serializer(), entry)) }.getOrNull()
        }
        return ReadResult(trackers, isBroken = false)
    }

    fun encode(trackers: List<Tracker>): String = json.encodeToString(
        JsonObject.serializer(),
        buildJsonObject {
            put(SCHEMA_VERSION, currentVersion)
            put(TRACKERS, json.encodeToJsonElement(ListSerializer(TrackerDto.serializer()), trackers.map(TrackerMapper::toDto)))
        },
    )

    private fun migrate(root: JsonObject): JsonObject {
        var version = root[SCHEMA_VERSION]?.jsonPrimitive?.intOrNull ?: 1
        var result = root
        while (version < currentVersion) {
            val step = migrations.firstOrNull { it.from == version } ?: break
            result = step.migrate(result)
            version++
        }
        return result
    }

    companion object {
        const val CURRENT_VERSION = 1

        /** Add a Migration(from = N) here when bumping [CURRENT_VERSION] to N + 1. */
        val MIGRATIONS = emptyList<Migration>()

        private const val SCHEMA_VERSION = "schemaVersion"
        private const val TRACKERS = "trackers"
    }
}
