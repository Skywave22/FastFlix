package dev.beamlak.flixquest_v2.downloads

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.documentfile.provider.DocumentFile
import org.json.JSONObject
import java.io.File
import java.io.IOException

/** Storage preference and per-title result. The private Media3 cache is never moved. */
internal class PublicDownloadSettings(context: Context) {
    private val app = context.applicationContext
    private val prefs = app.getSharedPreferences("fastflix_public_downloads", Context.MODE_PRIVATE)

    fun treeUri(): String = prefs.getString("tree_uri", "").orEmpty()
    fun setTreeUri(uri: String) { prefs.edit().putString("tree_uri", uri).apply() }
    fun locationMap(): Map<String, Any> = mapOf(
        "isDefault" to treeUri().isEmpty(),
        "label" to if (treeUri().isEmpty()) "Downloads/FlixQuest" else locationLabel(treeUri()),
    )

    private fun locationLabel(value: String): String = try {
        DocumentFile.fromTreeUri(app, Uri.parse(value))?.name ?: "Selected folder"
    } catch (_: Exception) { "Selected folder" }

    fun status(id: String): String? = prefs.getString("state:$id", null)
    fun error(id: String): String? = prefs.getString("error:$id", null)
    fun setStatus(id: String, state: String, error: String? = null, uri: String? = null) {
        prefs.edit().putString("state:$id", state).putString("error:$id", error)
            .putString("uri:$id", uri).apply()
    }
    fun clear(id: String) {
        prefs.edit().remove("state:$id").remove("error:$id").remove("uri:$id").apply()
    }
}

/** Names are safe as individual path components, but preserve non-Latin titles. */
internal object PublicDownloadNames {
    fun safe(value: String): String = value.replace(Regex("[\\\\/:*?\"<>|\\p{Cntrl}]"), "_")
        .trim().trim('.').take(100).ifBlank { "Video" }

    fun folder(metadata: JSONObject): List<String> {
        val title = safe(metadata.optString("title", "Video"))
        val id = metadata.optInt("contentId").takeIf { it > 0 }
        return if (metadata.optString("mediaType") == "episode") {
            listOf("FlixQuest", "Series", if (id != null) "$title ($id)" else title)
        } else {
            listOf("FlixQuest", "Movies")
        }
    }

    fun fileName(metadata: JSONObject): String {
        val title = safe(metadata.optString("title", "Video"))
        val id = metadata.optInt("contentId").takeIf { it > 0 }
        return if (metadata.optString("mediaType") == "episode") {
            val season = metadata.optInt("seasonNumber", -1).coerceAtLeast(0)
            val episode = metadata.optInt("episodeNumber", -1).coerceAtLeast(0)
            "S${season.toString().padStart(2, '0')}E${episode.toString().padStart(2, '0')}.mp4"
        } else {
            (if (id != null) "$title ($id)" else title) + ".mp4"
        }
    }
}

/** Publishes a completed remux atomically where the user can find it. */
internal class PublicDownloadDestination(private val context: Context) {
    fun copy(file: File, metadata: JSONObject, tree: String, cancelled: () -> Boolean): String {
        val folders = PublicDownloadNames.folder(metadata)
        val name = PublicDownloadNames.fileName(metadata)
        return if (tree.isNotEmpty()) copyToTree(file, Uri.parse(tree), folders, name, cancelled)
        else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) copyToMediaStore(file, folders, name, cancelled)
        else copyToLegacyDownloads(file, folders, name, cancelled)
    }

    private fun copyToTree(file: File, tree: Uri, folders: List<String>, name: String, cancelled: () -> Boolean): String {
        var directory = DocumentFile.fromTreeUri(context, tree)
            ?: throw IOException("The selected folder is no longer available. Choose another folder in download settings.")
        for (part in folders) {
            directory = directory.findFile(part) ?: directory.createDirectory(part)
                ?: throw IOException("Cannot create a folder in the selected location. Choose another folder.")
            if (!directory.isDirectory) throw IOException("A file is blocking the FlixQuest folder.")
        }
        val unique = uniqueName(name) { directory.findFile(it) != null }
        val output = directory.createFile("video/mp4", unique)
            ?: throw IOException("Cannot create a video in the selected folder.")
        try {
            context.contentResolver.openOutputStream(output.uri, "w").use { stream ->
                if (stream == null) throw IOException("Cannot write to the selected folder.")
                file.inputStream().use { input -> copyChecked(input, stream, cancelled) }
            }
            return output.uri.toString()
        } catch (error: Exception) {
            output.delete()
            throw error
        }
    }

    private fun copyToMediaStore(file: File, folders: List<String>, name: String, cancelled: () -> Boolean): String {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, name)
            put(MediaStore.Downloads.MIME_TYPE, "video/mp4")
            put(MediaStore.Downloads.RELATIVE_PATH, (listOf(Environment.DIRECTORY_DOWNLOADS) + folders).joinToString("/") + "/")
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val uri = resolver.insert(collection, values) ?: throw IOException("Cannot create the video in Downloads.")
        try {
            resolver.openOutputStream(uri, "w").use { output ->
                if (output == null) throw IOException("Cannot write the video to Downloads.")
                file.inputStream().use { input -> copyChecked(input, output, cancelled) }
            }
            if (cancelled()) throw IOException("Export cancelled.")
            resolver.update(uri, ContentValues().apply { put(MediaStore.Downloads.IS_PENDING, 0) }, null, null)
            return uri.toString()
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }
    }

    @Suppress("DEPRECATION")
    private fun copyToLegacyDownloads(file: File, folders: List<String>, name: String, cancelled: () -> Boolean): String {
        val root = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val directory = folders.fold(root) { parent, part -> File(parent, part) }
        if (!directory.isDirectory && !directory.mkdirs()) {
            throw IOException("Cannot write to Downloads. Allow storage access or choose a folder in download settings.")
        }
        val target = File(directory, uniqueName(name) { File(directory, it).exists() })
        // Keep incomplete files hidden and never overwrite a user's file.
        val temp = File.createTempFile(".fastflix-", ".partial", directory)
        try {
            temp.outputStream().use { output -> file.inputStream().use { input -> copyChecked(input, output, cancelled) } }
            if (cancelled() || !temp.renameTo(target)) throw IOException("Could not finish saving the video to Downloads.")
            android.media.MediaScannerConnection.scanFile(context, arrayOf(target.absolutePath), arrayOf("video/mp4"), null)
            return Uri.fromFile(target).toString()
        } catch (error: Exception) {
            temp.delete()
            throw error
        }
    }

    private fun copyChecked(input: java.io.InputStream, output: java.io.OutputStream, cancelled: () -> Boolean) {
        val buffer = ByteArray(128 * 1024)
        while (true) {
            if (cancelled()) throw IOException("Export cancelled.")
            val count = input.read(buffer)
            if (count < 0) break
            output.write(buffer, 0, count)
        }
        output.flush()
    }

    private fun uniqueName(name: String, exists: (String) -> Boolean): String {
        if (!exists(name)) return name
        val base = name.removeSuffix(".mp4")
        var index = 2
        while (exists("$base ($index).mp4")) index++
        return "$base ($index).mp4"
    }
}
