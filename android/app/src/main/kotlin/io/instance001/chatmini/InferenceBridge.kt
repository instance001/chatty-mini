package io.instance001.chatmini

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import org.json.JSONObject
import java.io.File
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean

class InferenceBridge {
    companion object {
        private const val WarnModelBytes = 1200L * 1024L * 1024L
        private const val FailModelBytes = 2200L * 1024L * 1024L
        private const val HighContextWarnThreshold = 1600L * 1024L * 1024L
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val nativeBridge = NativeLlamaBridge()
    private var eventSink: EventChannel.EventSink? = null
    private var activeRequestId: String? = null
    private var cancelled = AtomicBoolean(false)
    private var loadedModelPath: String? = null

    fun attachSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun loadModel(modelPath: String, contextSize: Int, gpuLayers: Int): Map<String, Any> {
        val modelFile = File(modelPath)
        if (!modelFile.exists()) {
            return mapOf(
                "state" to "failed",
                "message" to "Model file not found at $modelPath"
            )
        }
        val compatibilityIssue = compatibilityIssueFor(modelFile, contextSize)
        if (compatibilityIssue != null) {
            return mapOf(
                "state" to "failed",
                "message" to compatibilityIssue
            )
        }
        val loaded = nativeBridge.loadModel(modelPath, contextSize, gpuLayers)
        if (!loaded) {
            return mapOf(
                "state" to "failed",
                "message" to nativeBridge.getLastError()
            )
        }
        loadedModelPath = modelPath
        val advisory = advisoryFor(modelFile, contextSize)
        return mapOf(
            "state" to "loaded",
            "modelPath" to modelPath,
            "message" to (advisory ?: "Native llama.cpp model loaded via JNI."),
            "contextSize" to contextSize
        )
    }

    fun startGeneration(
        prompt: String,
        modelPath: String,
        contextSize: Int,
        maxTokens: Int,
        temperature: Double,
        topP: Double,
        topK: Int,
        gpuLayers: Int
    ): Map<String, Any> {
        val modelFile = File(modelPath)
        if (!modelFile.exists()) {
            return mapOf(
                "state" to "failed",
                "message" to "Model file not found at $modelPath"
            )
        }
        val compatibilityIssue = compatibilityIssueFor(modelFile, contextSize)
        if (compatibilityIssue != null) {
            return mapOf(
                "state" to "failed",
                "message" to compatibilityIssue
            )
        }

        if (activeRequestId != null) {
            return mapOf(
                "state" to "failed",
                "message" to "Another local generation is already running."
            )
        }

        if (loadedModelPath != modelPath) {
            loadedModelPath = modelPath
        }

        val requestId = "req-" + UUID.randomUUID().toString()
        activeRequestId = requestId
        cancelled = AtomicBoolean(false)
        emit(
            mapOf(
                "type" to "started",
                "requestId" to requestId
            )
        )

        Thread {
            val started = nativeBridge.startGeneration(
                requestId = requestId,
                modelPath = modelPath,
                prompt = prompt,
                contextSize = contextSize,
                maxTokens = maxTokens,
                temperature = temperature,
                topP = topP,
                topK = topK,
                gpuLayers = gpuLayers,
                callback = object : NativeGenerationCallback {
                    override fun onToken(requestId: String, text: String) {
                        emit(
                            mapOf(
                                "type" to "token",
                                "requestId" to requestId,
                                "text" to text
                            )
                        )
                    }

                    override fun onCompleted(requestId: String, text: String) {
                        activeRequestId = null
                        emit(
                            mapOf(
                                "type" to "completed",
                                "requestId" to requestId,
                                "text" to text
                            )
                        )
                    }

                    override fun onFailed(requestId: String, message: String) {
                        activeRequestId = null
                        emit(
                            mapOf(
                                "type" to "failed",
                                "requestId" to requestId,
                                "message" to message
                            )
                        )
                    }

                    override fun onCancelled(requestId: String) {
                        activeRequestId = null
                        emit(
                            mapOf(
                                "type" to "cancelled",
                                "requestId" to requestId
                            )
                        )
                    }
                }
            )
            if (!started) {
                activeRequestId = null
                emit(
                    mapOf(
                        "type" to "failed",
                        "requestId" to requestId,
                        "message" to "Native generation could not be started."
                    )
                )
            }
        }.start()

        return mapOf(
            "state" to "generating",
            "requestId" to requestId,
            "message" to "Local llama.cpp generation started."
        )
    }

    fun cancelGeneration(requestId: String) {
        if (activeRequestId == requestId) {
            cancelled.set(true)
            nativeBridge.requestCancelGeneration()
        }
    }

    private fun emit(payload: Map<String, Any>) {
        mainHandler.post {
            eventSink?.success(JSONObject(payload).toMap())
        }
    }

    private fun compatibilityIssueFor(modelFile: File, contextSize: Int): String? {
        val size = modelFile.length()
        if (size >= FailModelBytes) {
            return "`${modelFile.name}` is probably too large for the small-phone target. Try a lighter GGUF before loading it on devices like the Samsung A21s."
        }
        if (contextSize >= 2048 && size >= HighContextWarnThreshold) {
            return "`${modelFile.name}` is too heavy for the selected roomy context on a small phone. Pick a tighter preset or a smaller GGUF."
        }
        return null
    }

    private fun advisoryFor(modelFile: File, contextSize: Int): String? {
        val size = modelFile.length()
        return if (size >= WarnModelBytes) {
            "`${modelFile.name}` loaded, but it is large for a small phone. Watch for slower startup or memory pressure, especially above context $contextSize."
        } else {
            null
        }
    }

}

private fun JSONObject.toMap(): Map<String, Any> {
    val map = mutableMapOf<String, Any>()
    val iterator = keys()
    while (iterator.hasNext()) {
        val key = iterator.next()
        map[key] = get(key)
    }
    return map
}
