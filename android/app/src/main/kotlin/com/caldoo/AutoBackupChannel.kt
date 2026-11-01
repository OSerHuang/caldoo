package com.caldoo

import android.app.Activity
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.charset.StandardCharsets
import java.util.concurrent.Executors

/**
 * The platform half of the automatic off-app backup.
 *
 * Writes the backup JSON to the PUBLIC downloads area, `Download/caldoo/`,
 * never to the app's own storage: an uninstall deletes everything the app
 * owns, and surviving an uninstall is the whole point of this channel.
 *
 * * Android 10+ (`MediaStore.Downloads`): no permission needed. The documents
 *   appear in `Download/caldoo` and survive an uninstall.
 * * Android 9 and below: no scoped-storage exemption is available without the
 *   legacy WRITE_EXTERNAL_STORAGE runtime permission, so the copy goes to the
 *   app-specific external downloads directory instead (no permission; visible
 *   to a file manager, but removed with the app). The UI states the folder.
 *
 * `pickFile` uses the Storage Access Framework, so a `data.json` produced by a
 * PREVIOUS install (not readable through MediaStore ownership rules) can still
 * be imported by the user in one tap.
 */
class AutoBackupChannel(private val activity: Activity) {

    companion object {
        const val CHANNEL = "caldoo/auto_backup"

        /** Folder under the public Download directory. */
        private const val FOLDER = "caldoo"
        private const val MIME_JSON = "application/json"
        private const val NAME_COLUMN = MediaStore.MediaColumns.DISPLAY_NAME
        private const val SIZE_COLUMN = MediaStore.MediaColumns.SIZE
        private const val MODIFIED_COLUMN = MediaStore.MediaColumns.DATE_MODIFIED
        private const val RELATIVE_COLUMN = MediaStore.MediaColumns.RELATIVE_PATH
        private const val PICK_REQUEST = 0x5A17
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()

    /** The pending SAF pick result; only one pick may be open at a time. */
    private var pendingPick: MethodChannel.Result? = null

    /** Dispatches one channel call. IO methods run off the main thread. */
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(true)
            "save" -> {
                val name = call.argument<String>("name")
                val json = call.argument<String>("json")
                if (name.isNullOrBlank() || json == null) {
                    result.error("bad_args", "name and json are required", null)
                    return
                }
                onIo(result) { save(name, json); true }
            }
            "list" -> onIo(result) { list() }
            "read" -> {
                val name = call.argument<String>("name")
                if (name.isNullOrBlank()) {
                    result.error("bad_args", "name is required", null)
                    return
                }
                onIo(result) { read(name) }
            }
            "delete" -> {
                val name = call.argument<String>("name")
                if (name.isNullOrBlank()) {
                    result.error("bad_args", "name is required", null)
                    return
                }
                onIo(result) { delete(name); true }
            }
            "pickFile" -> pickFile(result)
            else -> result.notImplemented()
        }
    }

    /** Runs [block] on the IO thread, answering [result] on the main thread. */
    private fun <T> onIo(result: MethodChannel.Result, block: () -> T) {
        io.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (error: Throwable) {
                val message = error.message ?: error.javaClass.simpleName
                mainHandler.post { result.error("auto_backup_failed", message, null) }
            }
        }
    }

    // --- documents ---------------------------------------------------------

    private fun save(name: String, json: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveViaMediaStore(name, json)
        } else {
            LegacyFolder().write(name, json)
        }
    }

    private fun saveViaMediaStore(name: String, json: String) {
        val resolver = activity.contentResolver
        // A re-run with the same name (same second) replaces its own document.
        delete(name)
        val values = ContentValues().apply {
            put(NAME_COLUMN, name)
            put(MediaStore.MediaColumns.MIME_TYPE, MIME_JSON)
            put(RELATIVE_COLUMN, "${Environment.DIRECTORY_DOWNLOADS}/$FOLDER")
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("MediaStore rejected the backup document")
        try {
            resolver.openOutputStream(uri)?.use { stream ->
                stream.write(json.toByteArray(StandardCharsets.UTF_8))
            } ?: throw IllegalStateException("Cannot open the backup document")
            val done = ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }
            resolver.update(uri, done, null, null)
        } catch (error: Throwable) {
            resolver.delete(uri, null, null)
            throw error
        }
    }

    private fun list(): List<Map<String, Any>> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return listViaMediaStore()
        }
        return LegacyFolder().list()
    }

    private fun listViaMediaStore(): List<Map<String, Any>> {
        val resolver = activity.contentResolver
        val projection = arrayOf(NAME_COLUMN, SIZE_COLUMN, MODIFIED_COLUMN)
        val documents = mutableListOf<Map<String, Any>>()
        resolver.query(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            projection,
            "$RELATIVE_COLUMN LIKE ?",
            arrayOf("%$FOLDER%"),
            "$MODIFIED_COLUMN DESC",
        )?.use { cursor ->
            val nameIndex = cursor.getColumnIndexOrThrow(NAME_COLUMN)
            val sizeIndex = cursor.getColumnIndexOrThrow(SIZE_COLUMN)
            val modifiedIndex = cursor.getColumnIndexOrThrow(MODIFIED_COLUMN)
            while (cursor.moveToNext()) {
                documents.add(
                    mapOf(
                        "name" to cursor.getString(nameIndex),
                        "sizeBytes" to cursor.getLong(sizeIndex),
                        // DATE_MODIFIED is seconds since the epoch.
                        "modifiedMillis" to cursor.getLong(modifiedIndex) * 1000L,
                    ),
                )
            }
        }
        return documents
    }

    private fun read(name: String): String? {
        val uri = findUri(name) ?: return null
        return activity.contentResolver.openInputStream(uri)?.use { stream ->
            stream.readBytes().toString(StandardCharsets.UTF_8)
        }
    }

    private fun delete(name: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            LegacyFolder().delete(name)
            return
        }
        val uri = findUri(name) ?: return
        try {
            activity.contentResolver.delete(uri, null, null)
        } catch (_: SecurityException) {
            // A document written by a previous install is not ours to delete.
        }
    }

    private fun findUri(name: String): Uri? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return LegacyFolder().uriOf(name)
        }
        val resolver = activity.contentResolver
        resolver.query(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            arrayOf(MediaStore.MediaColumns._ID),
            "$NAME_COLUMN = ? AND $RELATIVE_COLUMN LIKE ?",
            arrayOf(name, "%$FOLDER%"),
            "$MODIFIED_COLUMN DESC",
        )?.use { cursor ->
            if (cursor.moveToNext()) {
                val id = cursor.getLong(0)
                return ContentUris.withAppendedId(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    id,
                )
            }
        }
        return null
    }

    // --- SAF import --------------------------------------------------------

    private fun pickFile(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("busy", "A file picker is already open", null)
            return
        }
        pendingPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
        }
        try {
            activity.startActivityForResult(intent, PICK_REQUEST)
        } catch (error: Throwable) {
            pendingPick = null
            result.error("pick_failed", error.message, null)
        }
    }

    /** Called from [MainActivity.onActivityResult]; true when handled here. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_REQUEST) {
            return false
        }
        val result = pendingPick ?: return true
        pendingPick = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        io.execute {
            try {
                val text = activity.contentResolver.openInputStream(uri)?.use { stream ->
                    stream.readBytes().toString(StandardCharsets.UTF_8)
                }
                mainHandler.post { result.success(text) }
            } catch (error: Throwable) {
                val message = error.message ?: error.javaClass.simpleName
                mainHandler.post { result.error("read_failed", message, null) }
            }
        }
        return true
    }

    /**
     * Android 9 and below: no permission-free PUBLIC downloads access exists,
     * so this fallback uses the app-specific external downloads directory
     * (removed with the app; the screen says so).
     */
    private inner class LegacyFolder {
        private val folder: File by lazy {
            val base = activity.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                ?: activity.filesDir
            File(base, FOLDER).apply { mkdirs() }
        }

        fun write(name: String, json: String) {
            File(folder, name).writeText(json, StandardCharsets.UTF_8)
        }

        fun list(): List<Map<String, Any>> {
            val files = folder.listFiles() ?: return emptyList()
            return files
                .filter { it.isFile && it.name.startsWith("data-") }
                .sortedByDescending { it.lastModified() }
                .map {
                    mapOf(
                        "name" to it.name,
                        "sizeBytes" to it.length(),
                        "modifiedMillis" to it.lastModified(),
                    )
                }
        }

        fun delete(name: String) {
            File(folder, name).delete()
        }

        fun uriOf(name: String): Uri? {
            val file = File(folder, name)
            return if (file.exists()) Uri.fromFile(file) else null
        }
    }
}
