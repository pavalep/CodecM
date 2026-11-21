package com.app.codecm

import android.app.PictureInPictureParams
import android.os.Build
import android.util.Rational
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : AudioServiceActivity() {
    private val PIP_CHANNEL = "com.app.codecm/pip"
    private val AI_CHANNEL = "com.app.codecm/gemma_litert"

    private var gemmaEngine: GemmaLiteRtEngine? = null
    private var searchDbHelper: SearchDatabaseHelper? = null
    private val aiExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Picture-in-Picture MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "enterPip") {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    try {
                        val rational = Rational(16, 9)
                        val params = PictureInPictureParams.Builder()
                            .setAspectRatio(rational)
                            .build()
                        val success = enterPictureInPictureMode(params)
                        result.success(success)
                    } catch (e: Exception) {
                        result.error("PIP_ERROR", e.message, null)
                    }
                } else {
                    result.error("UNSUPPORTED", "PiP requires Android Oreo or higher", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // 2. Gemma 2B LiteRT On-Device AI Engine & SQLite Search Suggestion MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AI_CHANNEL).setMethodCallHandler { call, result ->
            val engine = gemmaEngine ?: GemmaLiteRtEngine(applicationContext).also { gemmaEngine = it }
            val searchDb = searchDbHelper ?: SearchDatabaseHelper(applicationContext, engine).also { searchDbHelper = it }

            when (call.method) {
                "initializeEngine" -> {
                    aiExecutor.execute {
                        try {
                            val status = engine.initializeRuntime()
                            // Warm up SQLite database & pre-computed Gemma vectors
                            searchDb.readableDatabase
                            runOnUiThread { result.success(status) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("INIT_ERROR", e.message, null) }
                        }
                    }
                }
                "getSearchSuggestions" -> {
                    val prefix = call.argument<String>("prefix") ?: ""
                    val kind = call.argument<String>("kind") ?: "all"
                    val tasteContext = call.argument<String>("tasteContext") ?: ""
                    val limit = call.argument<Int>("limit") ?: 8
                    aiExecutor.execute {
                        try {
                            val bundle = searchDb.getSearchSuggestions(prefix, kind, tasteContext, limit)
                            runOnUiThread { result.success(bundle) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("SEARCH_SUGGEST_ERROR", e.message, null) }
                        }
                    }
                }
                "recordSearchQuery" -> {
                    val query = call.argument<String>("query") ?: ""
                    val kind = call.argument<String>("kind") ?: "all"
                    aiExecutor.execute {
                        try {
                            val recent = searchDb.recordSearchQuery(query, kind)
                            runOnUiThread { result.success(recent) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("SEARCH_RECORD_ERROR", e.message, null) }
                        }
                    }
                }
                "getRecentSearches" -> {
                    val limit = call.argument<Int>("limit") ?: 10
                    aiExecutor.execute {
                        try {
                            val recent = searchDb.getRecentSearches(limit)
                            runOnUiThread { result.success(recent) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("SEARCH_RECENT_ERROR", e.message, null) }
                        }
                    }
                }
                "deleteRecentSearch" -> {
                    val query = call.argument<String>("query") ?: ""
                    aiExecutor.execute {
                        try {
                            val recent = searchDb.deleteRecentSearch(query)
                            runOnUiThread { result.success(recent) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("SEARCH_DELETE_ERROR", e.message, null) }
                        }
                    }
                }
                "clearRecentSearches" -> {
                    aiExecutor.execute {
                        try {
                            searchDb.clearRecentSearches()
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("SEARCH_CLEAR_ERROR", e.message, null) }
                        }
                    }
                }
                "getEngineStatus" -> {
                    result.success(engine.getStatus())
                }
                "embedText" -> {
                    val text = call.argument<String>("text") ?: ""
                    aiExecutor.execute {
                        try {
                            val vec = engine.embedText(text)
                            runOnUiThread { result.success(vec.map { it.toDouble() }) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("EMBED_ERROR", e.message, null) }
                        }
                    }
                }
                "computeSimilarity" -> {
                    val textA = call.argument<String>("textA") ?: ""
                    val textB = call.argument<String>("textB") ?: ""
                    aiExecutor.execute {
                        try {
                            val vecA = engine.embedText(textA)
                            val vecB = engine.embedText(textB)
                            val score = engine.cosineSimilarity(vecA, vecB)
                            runOnUiThread { result.success(score) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("SIM_ERROR", e.message, null) }
                        }
                    }
                }
                "rankCandidates" -> {
                    val queryContext = call.argument<String>("queryContext") ?: ""
                    @Suppress("UNCHECKED_CAST")
                    val candidates = call.argument<List<Map<String, Any?>>>("candidates") ?: emptyList()
                    aiExecutor.execute {
                        try {
                            val ranked = engine.rankCandidates(queryContext, candidates)
                            runOnUiThread { result.success(ranked) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("RANK_ERROR", e.message, null) }
                        }
                    }
                }
                "generateDjSynthesis" -> {
                    val userTopics = call.argument<List<String>>("userTopics") ?: emptyList()
                    val recentTitles = call.argument<List<String>>("recentTitles") ?: emptyList()
                    val catalogTitles = call.argument<List<String>>("catalogTitles") ?: emptyList()
                    aiExecutor.execute {
                        try {
                            val synthesis = engine.generateDjSynthesis(userTopics, recentTitles, catalogTitles)
                            runOnUiThread { result.success(synthesis) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("DJ_ERROR", e.message, null) }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        searchDbHelper?.close()
        gemmaEngine?.close()
        aiExecutor.shutdown()
        super.onDestroy()
    }
}
