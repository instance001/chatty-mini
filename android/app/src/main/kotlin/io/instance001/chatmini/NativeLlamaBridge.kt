package io.instance001.chatmini

import androidx.annotation.Keep

@Keep
class NativeLlamaBridge {
    private var callback: NativeGenerationCallback? = null

    fun isAvailable(): Boolean = libraryLoaded

    fun getEngineInfo(): String {
        return if (libraryLoaded) {
            nativeGetEngineInfo()
        } else {
            "chatty-llama-stub unavailable | native library not loaded"
        }
    }

    fun loadModel(modelPath: String, contextSize: Int, gpuLayers: Int): Boolean {
        return libraryLoaded && nativeLoadModel(modelPath, contextSize, gpuLayers)
    }

    fun getLastError(): String {
        return if (libraryLoaded) {
            nativeGetLastError()
        } else {
            "Native library is unavailable."
        }
    }

    fun startGeneration(
        requestId: String,
        modelPath: String,
        prompt: String,
        contextSize: Int,
        maxTokens: Int,
        temperature: Double,
        topP: Double,
        topK: Int,
        gpuLayers: Int,
        callback: NativeGenerationCallback
    ): Boolean {
        if (!libraryLoaded) {
            return false
        }
        this.callback = callback
        return nativeStartGeneration(
            requestId,
            modelPath,
            prompt,
            contextSize,
            maxTokens,
            temperature,
            topP,
            topK,
            gpuLayers
        )
    }

    fun requestCancelGeneration() {
        if (libraryLoaded) {
            nativeRequestCancel()
        }
    }

    fun unloadModel() {
        if (libraryLoaded) {
            nativeUnloadModel()
        }
    }

    fun onNativeToken(requestId: String, text: String) {
        callback?.onToken(requestId, text)
    }

    fun onNativeCompleted(requestId: String, text: String) {
        callback?.onCompleted(requestId, text)
    }

    fun onNativeFailed(requestId: String, message: String) {
        callback?.onFailed(requestId, message)
    }

    fun onNativeCancelled(requestId: String) {
        callback?.onCancelled(requestId)
    }

    external fun nativeGetEngineInfo(): String
    external fun nativeLoadModel(modelPath: String, contextSize: Int, gpuLayers: Int): Boolean
    external fun nativeGetLastError(): String
    external fun nativeStartGeneration(
        requestId: String,
        modelPath: String,
        prompt: String,
        contextSize: Int,
        maxTokens: Int,
        temperature: Double,
        topP: Double,
        topK: Int,
        gpuLayers: Int
    ): Boolean
    external fun nativeRequestCancel()
    external fun nativeUnloadModel()

    companion object {
        private var libraryLoaded = false

        init {
            libraryLoaded = try {
                System.loadLibrary("chatty_llama")
                true
            } catch (_: UnsatisfiedLinkError) {
                false
            } catch (_: SecurityException) {
                false
            }
        }
    }
}

interface NativeGenerationCallback {
    fun onToken(requestId: String, text: String)
    fun onCompleted(requestId: String, text: String)
    fun onFailed(requestId: String, message: String)
    fun onCancelled(requestId: String)
}
