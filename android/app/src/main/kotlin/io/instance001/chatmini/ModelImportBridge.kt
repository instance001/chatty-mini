package io.instance001.chatmini

import android.content.ContentResolver
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

class ModelImportBridge(private val contentResolver: ContentResolver) {
    fun importUriToModelsDir(uri: Uri, modelsDirPath: String): String {
        val modelsDir = File(modelsDirPath)
        if (!modelsDir.exists()) {
            modelsDir.mkdirs()
        }

        val displayName = queryDisplayName(uri) ?: "imported_model.gguf"
        val sanitizedName = sanitizeModelFileName(displayName)
        val destination = resolveUniqueModelFile(modelsDir, sanitizedName)

        contentResolver.openInputStream(uri).use { input ->
            if (input == null) {
                throw IllegalStateException("Unable to open selected model stream.")
            }
            copyToFile(input, destination)
        }

        return destination.name
    }

    private fun queryDisplayName(uri: Uri): String? {
        val cursor: Cursor? = contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null
        )
        cursor.use {
            if (it != null && it.moveToFirst()) {
                val index = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) {
                    return it.getString(index)
                }
            }
        }
        return null
    }

    private fun copyToFile(input: InputStream, destination: File) {
        FileOutputStream(destination).use { output ->
            input.copyTo(output)
        }
    }

    private fun sanitizeModelFileName(input: String): String {
        val sanitized = input
            .trim()
            .replace(Regex("[^a-zA-Z0-9_\\-./ ]"), "")
            .replace(' ', '_')
        require(sanitized.isNotEmpty()) { "Model file name cannot be empty." }
        require(!sanitized.contains("..")) { "Model file name cannot contain '..'." }
        return if (sanitized.lowercase().endsWith(".gguf")) sanitized else "$sanitized.gguf"
    }

    private fun resolveUniqueModelFile(modelsDir: File, fileName: String): File {
        val dotIndex = fileName.lowercase().lastIndexOf(".gguf")
        val stem = if (dotIndex > 0) fileName.substring(0, dotIndex) else fileName
        var candidate = File(modelsDir, fileName)
        var suffix = 2
        while (candidate.exists()) {
            candidate = File(modelsDir, "${stem}_$suffix.gguf")
            suffix += 1
        }
        return candidate
    }
}
