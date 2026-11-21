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

        // 2. Gemma 2B LiteRT On-Device AI Engine MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AI_CHANNEL).setMethodCallHandler { call, result ->
            val engine = gemmaEngine ?: GemmaLiteRtEngine(applicationContext).also { gemmaEngine = it }

            when (call.method) {
                "initializeEngine" -> {
                    aiExecutor.execute {
                        try {
                            val status = engine.initializeRuntime()
                            runOnUiThread { result.success(status) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("INIT_ERROR", e.message, null) }
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
        gemmaEngine?.close()
        aiExecutor.shutdown()
        super.onDestroy()
    }
}
