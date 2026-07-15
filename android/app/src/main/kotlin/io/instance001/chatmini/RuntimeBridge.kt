package io.instance001.chatmini

import android.app.ActivityManager
import android.content.Context
import java.io.File

class RuntimeBridge(private val context: Context) {
    private val nativeBridge = NativeLlamaBridge()

    fun getRuntimeStatus(runtimeDirPath: String): Map<String, Any> {
        val runtimeDir = File(runtimeDirPath)
        if (!runtimeDir.exists()) {
            runtimeDir.mkdirs()
        }
        val memoryInfo = ActivityManager.MemoryInfo()
        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        activityManager.getMemoryInfo(memoryInfo)

        return if (nativeBridge.isAvailable()) {
            mapOf(
                "state" to "ready",
                "installMode" to "bundled",
                "message" to "Bundled native runtime is packaged with the app build.",
                "version" to "bundled-native-stub-v1",
                "backend" to "cpu",
                "deviceTotalRamBytes" to memoryInfo.totalMem,
                "deviceAvailableRamBytes" to memoryInfo.availMem,
                "lowRamDevice" to activityManager.isLowRamDevice,
                "memoryTrimSuggested" to memoryInfo.lowMemory
            )
        } else {
            mapOf(
                "state" to "missing",
                "installMode" to "bundled",
                "message" to "Bundled native runtime is unavailable in this build. Rebuild the app with the packaged native library.",
                "backend" to "unavailable",
                "deviceTotalRamBytes" to memoryInfo.totalMem,
                "deviceAvailableRamBytes" to memoryInfo.availMem,
                "lowRamDevice" to activityManager.isLowRamDevice,
                "memoryTrimSuggested" to memoryInfo.lowMemory
            )
        }
    }
}
