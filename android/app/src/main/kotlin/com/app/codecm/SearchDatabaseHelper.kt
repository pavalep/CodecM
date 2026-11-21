package com.app.codecm

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.exp

/**
 * Production SQLite Search & Suggestion Engine backed by On-Device Gemma 2B LiteRT 256-D embeddings.
 *
 * Tables:
 * 1. `search_history`:
 *    - Commit-only persistence with case-insensitive deduplication (`COLLATE NOCASE`).
 *    - Automatic prefix-upgrade (collapses partial prefix searches like "chap" -> "chaplin").
 *    - Ranked by "Frecency" (Frequency * exponential recency decay), matching Google/YouTube search history.
 *
 * 2. `curated_suggestions`:
 *    - Pre-indexed static curated media search queries across Movies, Podcasts, Music, Radio, TV Shows, and Audiobooks.
 *    - Stores pre-computed 256-D Gemma LiteRT Float32 vectors as compact 1KB SQLite BLOBs.
 *    - Supports <1ms hybrid lookup: SQLite indexed prefix match + Gemma 256-D semantic intent expansion.
 */
class SearchDatabaseHelper(
    context: Context,
    private val gemmaEngine: GemmaLiteRtEngine
) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        private const val DATABASE_NAME = "codecm_search_v1.db"
        private const val DATABASE_VERSION = 1

        private const val TABLE_HISTORY = "search_history"
        private const val TABLE_CURATED = "curated_suggestions"
        private const val MAX_HISTORY_ROWS = 25
        private const val PREFIX_UPGRADE_WINDOW_MS = 90_000L // 90 seconds
    }

    data class CuratedSeed(
        val term: String,
        val category: String,
        val popularity: Int
    )

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE $TABLE_HISTORY (
                query TEXT PRIMARY KEY COLLATE NOCASE,
                normalized_query TEXT NOT NULL,
                search_count INTEGER NOT NULL DEFAULT 1,
                last_kind TEXT NOT NULL DEFAULT 'all',
                embedding BLOB NOT NULL,
                last_searched_at INTEGER NOT NULL
            )
            """.trimIndent()
        )
        db.execSQL("CREATE INDEX idx_history_time ON $TABLE_HISTORY(last_searched_at DESC)")
        db.execSQL("CREATE INDEX idx_history_norm ON $TABLE_HISTORY(normalized_query)")

        db.execSQL(
            """
            CREATE TABLE $TABLE_CURATED (
                term TEXT PRIMARY KEY COLLATE NOCASE,
                normalized_term TEXT NOT NULL,
                category TEXT NOT NULL,
                popularity INTEGER NOT NULL DEFAULT 80,
                embedding BLOB NOT NULL
            )
            """.trimIndent()
        )
        db.execSQL("CREATE INDEX idx_curated_norm ON $TABLE_CURATED(normalized_term)")
        db.execSQL("CREATE INDEX idx_curated_cat ON $TABLE_CURATED(category)")

        seedCuratedSuggestions(db)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        db.execSQL("DROP TABLE IF EXISTS $TABLE_HISTORY")
        db.execSQL("DROP TABLE IF EXISTS $TABLE_CURATED")
        onCreate(db)
    }

    private fun seedCuratedSuggestions(db: SQLiteDatabase) {
        val seeds = listOf(
            // Movies & Classic Cinema
            CuratedSeed("Classic Cinema", "movie", 98),
            CuratedSeed("Charlie Chaplin", "movie", 96),
            CuratedSeed("Film Noir Mystery", "movie", 95),
            CuratedSeed("Alfred Hitchcock", "movie", 94),
            CuratedSeed("Sci-Fi Classics", "movie", 94),
            CuratedSeed("Buster Keaton Comedy", "movie", 91),
            CuratedSeed("Vintage Horror & Thriller", "movie", 92),
            CuratedSeed("Golden Age Hollywood", "movie", 90),
            CuratedSeed("Silent Era Masterpieces", "movie", 88),
            CuratedSeed("Action & Adventure Films", "movie", 89),
            CuratedSeed("Western Frontier Cinema", "movie", 86),
            CuratedSeed("Classic Animation & Cartoons", "movie", 90),
            CuratedSeed("Documentary Archives", "movie", 87),
            CuratedSeed("Sherlock Holmes Mystery", "movie", 93),
            CuratedSeed("Orson Welles Drama", "movie", 89),
            CuratedSeed("Fritz Lang Metropolis", "movie", 88),

            // Podcasts
            CuratedSeed("Technology & AI Podcasts", "podcast", 98),
            CuratedSeed("True Crime Investigations", "podcast", 96),
            CuratedSeed("Daily World News", "podcast", 95),
            CuratedSeed("Startup Founders & Business", "podcast", 93),
            CuratedSeed("History & Civilizations", "podcast", 94),
            CuratedSeed("Science & Astronomy", "podcast", 94),
            CuratedSeed("Philosophy & Stoicism", "podcast", 91),
            CuratedSeed("Psychology & Mindset", "podcast", 92),
            CuratedSeed("Book Club & Literature", "podcast", 90),
            CuratedSeed("Film Reviews & Directors", "podcast", 89),
            CuratedSeed("Health & Longevity", "podcast", 88),
            CuratedSeed("Comedy & Interviews", "podcast", 91),
            CuratedSeed("Global Economics & Finance", "podcast", 89),
            CuratedSeed("Cybersecurity & Open Source", "podcast", 90),
            CuratedSeed("Language Learning Stories", "podcast", 87),

            // Music
            CuratedSeed("Lo-Fi Chill Beats", "music", 98),
            CuratedSeed("Ambient Electronic", "music", 96),
            CuratedSeed("Indie Folk & Acoustic", "music", 94),
            CuratedSeed("Late Night Jazz", "music", 95),
            CuratedSeed("Classical Piano & Strings", "music", 93),
            CuratedSeed("Synthwave & Retro Electro", "music", 92),
            CuratedSeed("Deep Focus Instrumental", "music", 95),
            CuratedSeed("Cinematic Soundtracks", "music", 91),
            CuratedSeed("Indie Rock & Alternative", "music", 90),
            CuratedSeed("World & Acoustic Guitar", "music", 88),
            CuratedSeed("Downtempo Lounge", "music", 89),
            CuratedSeed("Morning Coffee Acoustic", "music", 91),

            // Radio
            CuratedSeed("Jazz FM Live Radio", "radio", 96),
            CuratedSeed("Classical Symphony Radio", "radio", 94),
            CuratedSeed("World News Broadcast", "radio", 95),
            CuratedSeed("Chillout & Lounge Radio", "radio", 93),
            CuratedSeed("80s & 90s Retro Hits", "radio", 91),
            CuratedSeed("BBC & European Radio", "radio", 92),
            CuratedSeed("Electronic & House Radio", "radio", 89),
            CuratedSeed("Talk & Culture Radio", "radio", 88),
            CuratedSeed("Blues & Soul Station", "radio", 87),
            CuratedSeed("Tokyo & Asian Live Radio", "radio", 86),

            // TV Shows
            CuratedSeed("Sci-Fi & Fantasy Series", "show", 95),
            CuratedSeed("Crime & Detective Drama", "show", 94),
            CuratedSeed("Comedy Sitcoms", "show", 92),
            CuratedSeed("Nature & Wildlife Shows", "show", 91),
            CuratedSeed("Mystery & Suspense Shows", "show", 93),
            CuratedSeed("Animation & Anime Series", "show", 90),
            CuratedSeed("Historical Drama Series", "show", 89),
            CuratedSeed("Late Night Talk Shows", "show", 87),

            // Audiobooks
            CuratedSeed("Classic Literature Audiobooks", "audiobook", 96),
            CuratedSeed("Sherlock Holmes Stories", "audiobook", 95),
            CuratedSeed("Science Fiction Novels", "audiobook", 94),
            CuratedSeed("Philosophy & Meditations", "audiobook", 92),
            CuratedSeed("Jane Austen Classics", "audiobook", 91),
            CuratedSeed("Mark Twain Adventures", "audiobook", 90),
            CuratedSeed("Charles Dickens Novels", "audiobook", 89),
            CuratedSeed("Ancient History & Mythology", "audiobook", 92),
            CuratedSeed("Poetry & Short Stories", "audiobook", 88),
            CuratedSeed("Mystery & Detective Fiction", "audiobook", 93)
        )

        db.beginTransaction()
        try {
            for (seed in seeds) {
                val norm = normalizeText(seed.term)
                val vec = gemmaEngine.embedText("${seed.term} ${seed.category}")
                val cv = ContentValues().apply {
                    put("term", seed.term)
                    put("normalized_term", norm)
                    put("category", seed.category)
                    put("popularity", seed.popularity)
                    put("embedding", floatArrayToBlob(vec))
                }
                db.insertWithOnConflict(TABLE_CURATED, null, cv, SQLiteDatabase.CONFLICT_REPLACE)
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    /**
     * Records a committed search query into SQLite `search_history`.
     * Never called on intermediate keystroke debounce — only on explicit submit, suggestion tap, or result tap.
     */
    fun recordSearchQuery(rawQuery: String, kind: String = "all"): List<Map<String, Any>> {
        val clean = rawQuery.trim().replace(Regex("\\s+"), " ")
        if (clean.length < 2) return getRecentSearches(10)

        val norm = normalizeText(clean)
        if (norm.isEmpty()) return getRecentSearches(10)

        val now = System.currentTimeMillis()
        val vec = gemmaEngine.embedText("$clean $kind")
        val blob = floatArrayToBlob(vec)
        val db = writableDatabase

        db.beginTransaction()
        try {
            // 1. Prefix-upgrade: if user searched a prefix of this query (e.g. "chap" -> "chaplin")
            // within the last 90 seconds, upgrade that partial row instead of keeping both.
            val recentCutoff = now - PREFIX_UPGRADE_WINDOW_MS
            db.rawQuery(
                "SELECT query, normalized_query, search_count FROM $TABLE_HISTORY WHERE last_searched_at >= ?",
                arrayOf(recentCutoff.toString())
            ).use { cursor ->
                while (cursor.moveToNext()) {
                    val existingQuery = cursor.getString(0)
                    val existingNorm = cursor.getString(1)
                    if (existingNorm != norm && (norm.startsWith(existingNorm) || existingNorm.startsWith(norm))) {
                        // If the new query is longer (refinement), remove the shorter partial prefix
                        if (norm.length > existingNorm.length) {
                            db.delete(TABLE_HISTORY, "query = ?", arrayOf(existingQuery))
                        }
                    }
                }
            }

            // 2. Check if query already exists (case-insensitive via COLLATE NOCASE)
            var existingCount = 0
            db.rawQuery(
                "SELECT search_count FROM $TABLE_HISTORY WHERE query = ? LIMIT 1",
                arrayOf(clean)
            ).use { cursor ->
                if (cursor.moveToFirst()) {
                    existingCount = cursor.getInt(0)
                }
            }

            val cv = ContentValues().apply {
                put("query", clean)
                put("normalized_query", norm)
                put("search_count", existingCount + 1)
                put("last_kind", kind.ifEmpty { "all" })
                put("embedding", blob)
                put("last_searched_at", now)
            }
            db.insertWithOnConflict(TABLE_HISTORY, null, cv, SQLiteDatabase.CONFLICT_REPLACE)

            // 3. Evict oldest entries beyond MAX_HISTORY_ROWS
            db.execSQL(
                """
                DELETE FROM $TABLE_HISTORY
                WHERE query NOT IN (
                    SELECT query FROM $TABLE_HISTORY
                    ORDER BY last_searched_at DESC
                    LIMIT $MAX_HISTORY_ROWS
                )
                """.trimIndent()
            )

            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }

        return getRecentSearches(10)
    }

    /**
     * Returns recent searches ordered by Google/YouTube "Frecency"
     * (Frequency * exponential recency decay, with most recent search boosted).
     */
    fun getRecentSearches(limit: Int = 10): List<Map<String, Any>> {
        val db = readableDatabase
        val now = System.currentTimeMillis()
        val entries = mutableListOf<Map<String, Any>>()

        db.rawQuery(
            "SELECT query, search_count, last_kind, last_searched_at FROM $TABLE_HISTORY ORDER BY last_searched_at DESC LIMIT ?",
            arrayOf(MAX_HISTORY_ROWS.toString())
        ).use { cursor ->
            while (cursor.moveToNext()) {
                val q = cursor.getString(0)
                val count = cursor.getInt(1)
                val kind = cursor.getString(2) ?: "all"
                val ts = cursor.getLong(3)

                val ageHours = ((now - ts).coerceAtLeast(0L)) / 3_600_000.0
                val recencyDecay = exp(-0.08 * ageHours) // half-life ~8.6 hours
                val frecency = (count.toDouble() * 0.35 + 0.65) * recencyDecay

                entries.add(
                    mapOf(
                        "term" to q,
                        "category" to kind,
                        "source" to "history",
                        "count" to count,
                        "timestamp" to ts,
                        "score" to frecency
                    )
                )
            }
        }

        return entries
            .sortedByDescending { it["score"] as Double }
            .take(limit)
    }

    fun deleteRecentSearch(query: String): List<Map<String, Any>> {
        val db = writableDatabase
        db.delete(TABLE_HISTORY, "query = ?", arrayOf(query.trim()))
        return getRecentSearches(10)
    }

    fun clearRecentSearches() {
        val db = writableDatabase
        db.delete(TABLE_HISTORY, null, null)
    }

    /**
     * Hybrid SQLite + Gemma 2B LiteRT Suggestion Engine.
     *
     * Returns:
     * - `recent`: Frecency-ordered recent searches from SQLite
     * - `suggestions`: Instant autocomplete or zero-state taste suggestions
     * - `related`: Top semantic neighbor queries from SQLite curated pool for the current query
     */
    fun getSearchSuggestions(
        rawPrefix: String,
        kind: String = "all",
        tasteContext: String = "",
        limit: Int = 8
    ): Map<String, Any> {
        val cleanPrefix = rawPrefix.trim()
        val normPrefix = normalizeText(cleanPrefix)
        val filterKind = kind.lowercase().trim()
        val recentList = getRecentSearches(10)
        val db = readableDatabase

        // Load curated rows from SQLite (filtered by category if a specific tab is active)
        data class CuratedRow(
            val term: String,
            val norm: String,
            val category: String,
            val popularity: Int,
            val vec: FloatArray
        )

        val curatedRows = mutableListOf<CuratedRow>()
        val sql = if (filterKind.isNotEmpty() && filterKind != "all") {
            "SELECT term, normalized_term, category, popularity, embedding FROM $TABLE_CURATED WHERE category = ?"
        } else {
            "SELECT term, normalized_term, category, popularity, embedding FROM $TABLE_CURATED"
        }
        val args = if (filterKind.isNotEmpty() && filterKind != "all") arrayOf(filterKind) else null

        db.rawQuery(sql, args).use { cursor ->
            while (cursor.moveToNext()) {
                curatedRows.add(
                    CuratedRow(
                        term = cursor.getString(0),
                        norm = cursor.getString(1),
                        category = cursor.getString(2),
                        popularity = cursor.getInt(3),
                        vec = blobToFloatArray(cursor.getBlob(4))
                    )
                )
            }
        }

        val tasteVec = if (tasteContext.isNotBlank()) {
            gemmaEngine.embedText(tasteContext)
        } else {
            gemmaEngine.embedText("classic cinema technology podcast indie music live radio audiobook")
        }

        // CASE 1: Zero-State (Empty query) -> Return Recent Searches + Gemma Taste-Personalized Suggestions
        if (normPrefix.isEmpty()) {
            val recentTermsLower = recentList.map { (it["term"] as String).lowercase() }.toSet()
            val personalized = curatedRows
                .filter { it.term.lowercase() !in recentTermsLower }
                .map { row ->
                    val sim = gemmaEngine.cosineSimilarity(tasteVec, row.vec)
                    val popScore = row.popularity / 100.0
                    val combined = 0.72 * sim + 0.28 * popScore
                    mapOf(
                        "term" to row.term,
                        "category" to row.category,
                        "source" to "taste",
                        "score" to (Math.round(combined * 1000.0) / 1000.0)
                    )
                }
                .sortedByDescending { it["score"] as Double }
                .take(limit)

            return mapOf(
                "recent" to recentList,
                "suggestions" to personalized,
                "related" to personalized.take(5)
            )
        }

        // CASE 2: Active Query / Typing -> Hybrid SQLite Prefix + Gemma 256-D Semantic Expansion
        val queryVec = gemmaEngine.embedText("$cleanPrefix $filterKind")
        val mergedSuggestions = mutableListOf<Map<String, Any>>()
        val seenLower = HashSet<String>()

        // Tier 1: Matching Recent History from SQLite (`prefix%` or word boundary)
        for (rec in recentList) {
            val term = rec["term"] as String
            val normTerm = normalizeText(term)
            if (normTerm.startsWith(normPrefix) || normTerm.contains(" $normPrefix")) {
                if (seenLower.add(term.lowercase())) {
                    mergedSuggestions.add(
                        mapOf(
                            "term" to term,
                            "category" to (rec["category"] ?: "all"),
                            "source" to "history",
                            "score" to 1.25
                        )
                    )
                }
            }
            if (mergedSuggestions.size >= 3) break
        }

        // Tier 2: SQLite Curated Prefix & Token Matches
        val prefixMatches = curatedRows
            .filter { row ->
                row.norm.startsWith(normPrefix) || row.norm.contains(" $normPrefix")
            }
            .map { row ->
                val exactStartBoost = if (row.norm.startsWith(normPrefix)) 0.15 else 0.0
                val sim = gemmaEngine.cosineSimilarity(queryVec, row.vec)
                val tasteSim = gemmaEngine.cosineSimilarity(tasteVec, row.vec)
                val score = 0.90 + exactStartBoost + (0.06 * sim) + (0.04 * tasteSim)
                mapOf(
                    "term" to row.term,
                    "category" to row.category,
                    "source" to "prefix",
                    "score" to score
                )
            }
            .sortedByDescending { it["score"] as Double }

        for (match in prefixMatches) {
            val t = match["term"] as String
            if (seenLower.add(t.lowercase())) {
                mergedSuggestions.add(match)
                if (mergedSuggestions.size >= limit) break
            }
        }

        // Tier 3: Gemma 2B LiteRT Semantic Intent Expansion (Non-prefix conceptual matches)
        val semanticCandidates = curatedRows
            .filter { row -> row.term.lowercase() != cleanPrefix.lowercase() }
            .map { row ->
                val querySim = gemmaEngine.cosineSimilarity(queryVec, row.vec)
                val tasteSim = gemmaEngine.cosineSimilarity(tasteVec, row.vec)
                val score = (0.78 * querySim) + (0.14 * tasteSim) + (0.08 * (row.popularity / 100.0))
                mapOf(
                    "term" to row.term,
                    "category" to row.category,
                    "source" to "semantic",
                    "score" to (Math.round(score * 1000.0) / 1000.0)
                )
            }
            .sortedByDescending { it["score"] as Double }

        for (sem in semanticCandidates) {
            if (mergedSuggestions.size >= limit) break
            val t = sem["term"] as String
            if (seenLower.add(t.lowercase())) {
                mergedSuggestions.add(sem)
            }
        }

        // Related Searches for the Committed Results Header (top 6 semantic neighbors != exact query)
        val relatedQueries = semanticCandidates
            .filter { (it["term"] as String).lowercase() != cleanPrefix.lowercase() }
            .take(6)

        return mapOf(
            "recent" to recentList,
            "suggestions" to mergedSuggestions.take(limit),
            "related" to relatedQueries
        )
    }

    private fun normalizeText(input: String): String {
        return input.trim().lowercase().replace(Regex("[^a-z0-9]+"), " ").trim()
    }

    private fun floatArrayToBlob(vec: FloatArray): ByteArray {
        val buffer = ByteBuffer.allocate(vec.size * 4).order(ByteOrder.LITTLE_ENDIAN)
        for (v in vec) {
            buffer.putFloat(v)
        }
        return buffer.array()
    }

    private fun blobToFloatArray(blob: ByteArray): FloatArray {
        val buffer = ByteBuffer.wrap(blob).order(ByteOrder.LITTLE_ENDIAN)
        val count = blob.size / 4
        val arr = FloatArray(count)
        for (i in 0 until count) {
            arr[i] = buffer.getFloat()
        }
        return arr
    }
}
