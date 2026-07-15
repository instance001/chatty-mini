package io.instance001.chatmini

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val modelImportRequestCode = 6012
    private val sandboxExportRequestCode = 6013
    private val sandboxImportRequestCode = 6014
    private val runtimeChannel = "chatty_mini/runtime_bridge"
    private val inferenceChannel = "chatty_mini/inference_bridge"
    private val inferenceEventsChannel = "chatty_mini/inference_events"
    private val modelImportChannel = "chatty_mini/model_import_bridge"
    private val cloudKeysChannel = "chatty_mini/cloud_keys"
    private val sandboxExportChannel = "chatty_mini/sandbox_export"
    private val externalLinksChannel = "chatty_mini/external_links"
    private val runtimeBridge by lazy { RuntimeBridge(applicationContext) }
    private val inferenceBridge = InferenceBridge()
    private val modelImportBridge by lazy { ModelImportBridge(contentResolver) }
    private val cloudKeyBridge by lazy { CloudKeyBridge(applicationContext) }
    private var pendingImportResult: MethodChannel.Result? = null
    private var pendingModelsDirPath: String? = null
    private var pendingExportResult: MethodChannel.Result? = null
    private var pendingExportBytes: ByteArray? = null
    private var pendingSandboxImportResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            runtimeChannel
        ).setMethodCallHandler { call, result ->
            val runtimeDirPath = call.argument<String>("runtimeDirPath")

            when (call.method) {
                "getRuntimeStatus" -> {
                    if (runtimeDirPath == null) {
                        result.error("missing_runtime_dir", "runtimeDirPath is required", null)
                    } else {
                        result.success(runtimeBridge.getRuntimeStatus(runtimeDirPath))
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            externalLinksChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openUrl" -> {
                    val rawUrl = call.argument<String>("url")
                    val uri = rawUrl?.let(Uri::parse)
                    if (uri == null || uri.scheme != "https") {
                        result.error("invalid_url", "A valid HTTPS URL is required.", null)
                    } else {
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, uri))
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("open_url_failed", error.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            cloudKeysChannel
        ).setMethodCallHandler { call, result ->
            val providerId = call.argument<String>("providerId")
            if (providerId == null) {
                result.error("missing_provider_id", "providerId is required", null)
                return@setMethodCallHandler
            }
            try {
                when (call.method) {
                    "save" -> {
                        val apiKey = call.argument<String>("apiKey")
                        if (apiKey.isNullOrBlank()) result.error("missing_api_key", "apiKey is required", null)
                        else { cloudKeyBridge.save(providerId, apiKey); result.success(null) }
                    }
                    "read" -> result.success(cloudKeyBridge.read(providerId))
                    "delete" -> { cloudKeyBridge.delete(providerId); result.success(null) }
                    "has" -> result.success(cloudKeyBridge.has(providerId))
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("cloud_key_error", error.message, null)
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            modelImportChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "importModels" -> {
                    val modelsDirPath = call.argument<String>("modelsDirPath")
                    if (modelsDirPath == null) {
                        result.error("missing_models_dir", "modelsDirPath is required", null)
                    } else if (pendingImportResult != null) {
                        result.error("import_in_progress", "Another model import is already running.", null)
                    } else {
                        pendingImportResult = result
                        pendingModelsDirPath = modelsDirPath
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                            type = "*/*"
                        }
                        startActivityForResult(intent, modelImportRequestCode)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            sandboxExportChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "exportFile" -> {
                    val fileName = call.argument<String>("fileName")
                    val bytes = call.argument<ByteArray>("bytes")
                    if (fileName.isNullOrBlank() || bytes == null) {
                        result.error("missing_export_args", "fileName and bytes are required", null)
                    } else if (pendingExportResult != null) {
                        result.error("export_in_progress", "Another export is already running.", null)
                    } else {
                        pendingExportResult = result
                        pendingExportBytes = bytes
                        val mimeType = when (fileName.substringAfterLast('.', "").lowercase()) {
                            "md" -> "text/markdown"
                            "json" -> "application/json"
                            else -> "text/plain"
                        }
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = mimeType
                            putExtra(Intent.EXTRA_TITLE, fileName)
                        }
                        startActivityForResult(intent, sandboxExportRequestCode)
                    }
                }
                "importFiles" -> {
                    if (pendingSandboxImportResult != null) {
                        result.error("import_in_progress", "Another sandbox import is already running.", null)
                    } else {
                        pendingSandboxImportResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                            type = "*/*"
                        }
                        startActivityForResult(intent, sandboxImportRequestCode)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            inferenceChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "loadModel" -> {
                    val modelPath = call.argument<String>("modelPath")
                    val contextSize = call.argument<Int>("contextSize") ?: 1536
                    val gpuLayers = call.argument<Int>("gpuLayers") ?: 0
                    if (modelPath == null) {
                        result.error("missing_model_path", "modelPath is required", null)
                    } else {
                        result.success(inferenceBridge.loadModel(modelPath, contextSize, gpuLayers))
                    }
                }
                "startGeneration" -> {
                    val prompt = call.argument<String>("prompt")
                    val modelPath = call.argument<String>("modelPath")
                    val contextSize = call.argument<Int>("contextSize") ?: 1536
                    val maxTokens = call.argument<Int>("maxTokens") ?: 160
                    val temperature = call.argument<Double>("temperature") ?: 0.72
                    val topP = call.argument<Double>("topP") ?: 0.92
                    val topK = call.argument<Int>("topK") ?: 40
                    val gpuLayers = call.argument<Int>("gpuLayers") ?: 0
                    if (prompt == null || modelPath == null) {
                        result.error("missing_generation_args", "prompt and modelPath are required", null)
                    } else {
                        result.success(
                            inferenceBridge.startGeneration(
                                prompt,
                                modelPath,
                                contextSize,
                                maxTokens,
                                temperature,
                                topP,
                                topK,
                                gpuLayers
                            )
                        )
                    }
                }
                "cancelGeneration" -> {
                    val requestId = call.argument<String>("requestId")
                    if (requestId == null) {
                        result.error("missing_request_id", "requestId is required", null)
                    } else {
                        inferenceBridge.cancelGeneration(requestId)
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            inferenceEventsChannel
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                inferenceBridge.attachSink(events)
            }

            override fun onCancel(arguments: Any?) {
                inferenceBridge.attachSink(null)
            }
        })
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == sandboxExportRequestCode) {
            val result = pendingExportResult
            val bytes = pendingExportBytes
            pendingExportResult = null
            pendingExportBytes = null
            if (result == null || bytes == null) return
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) {
                result.success(false)
                return
            }
            try {
                contentResolver.openOutputStream(uri, "w")?.use { stream ->
                    stream.write(bytes)
                } ?: throw IllegalStateException("Could not open the selected file.")
                result.success(true)
            } catch (error: Exception) {
                result.error("sandbox_export_failed", error.message, null)
            }
            return
        }
        if (requestCode == sandboxImportRequestCode) {
            val result = pendingSandboxImportResult
            pendingSandboxImportResult = null
            if (result == null) return
            if (resultCode != Activity.RESULT_OK || data == null) {
                result.success(emptyList<Map<String, Any>>())
                return
            }

            val uris = mutableListOf<Uri>()
            data.data?.let { uris.add(it) }
            val clipData = data.clipData
            if (clipData != null) {
                for (index in 0 until clipData.itemCount) {
                    uris.add(clipData.getItemAt(index).uri)
                }
            }

            try {
                val imported = uris.distinct().mapNotNull { uri ->
                    val fileName = queryDisplayName(uri) ?: uri.lastPathSegment ?: "imported.txt"
                    val extension = fileName.substringAfterLast('.', "").lowercase()
                    if (extension !in setOf("md", "txt", "json")) {
                        null
                    } else {
                        val text = contentResolver.openInputStream(uri)?.use { stream ->
                            stream.readBytes().toString(Charsets.UTF_8)
                        } ?: ""
                        mapOf("fileName" to fileName, "contents" to text)
                    }
                }
                result.success(imported)
            } catch (error: Exception) {
                result.error("sandbox_import_failed", error.message, null)
            }
            return
        }
        if (requestCode != modelImportRequestCode) {
            return
        }

        val result = pendingImportResult
        val modelsDirPath = pendingModelsDirPath
        pendingImportResult = null
        pendingModelsDirPath = null

        if (result == null || modelsDirPath == null) {
            return
        }

        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<String>())
            return
        }

        val uris = mutableListOf<Uri>()
        data.data?.let { uris.add(it) }
        val clipData = data.clipData
        if (clipData != null) {
            for (index in 0 until clipData.itemCount) {
                uris.add(clipData.getItemAt(index).uri)
            }
        }

        if (uris.isEmpty()) {
            result.success(emptyList<String>())
            return
        }

        try {
            val importedNames = uris.distinct().map { uri ->
                modelImportBridge.importUriToModelsDir(uri, modelsDirPath)
            }
            result.success(importedNames)
        } catch (error: Exception) {
            result.error("model_import_failed", error.message, null)
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        val cursor = contentResolver.query(uri, null, null, null, null) ?: return null
        cursor.use {
            val nameIndex = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            return if (nameIndex >= 0 && it.moveToFirst()) it.getString(nameIndex) else null
        }
    }
}
