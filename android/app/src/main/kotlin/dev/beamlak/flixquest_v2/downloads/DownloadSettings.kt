package dev.beamlak.flixquest_v2.downloads

import android.content.Context
import java.util.concurrent.ThreadPoolExecutor

/** Global download limits. Segment workers are shared by all active downloads. */
internal data class DownloadSettings(
    val segments: Int = 8,
    val parallelDownloads: Int = 2,
    val retryCount: Int = 6,
    val unmeteredOnly: Boolean = false,
) {
    fun toMap(): Map<String, Any> = mapOf(
        "segments" to segments,
        "parallelDownloads" to parallelDownloads,
        "retryCount" to retryCount,
        "unmeteredOnly" to unmeteredOnly,
    )

    companion object {
        fun fromMap(values: Map<*, *>): DownloadSettings = DownloadSettings(
            segments = ((values["segments"] as? Number)?.toInt() ?: 8).coerceIn(1, 16),
            parallelDownloads = ((values["parallelDownloads"] as? Number)?.toInt() ?: 2).coerceIn(1, 4),
            retryCount = ((values["retryCount"] as? Number)?.toInt() ?: 6).coerceIn(0, 10),
            unmeteredOnly = values["unmeteredOnly"] as? Boolean ?: false,
        )
    }
}

internal class DownloadSettingsStore(context: Context) {
    private val preferences = context.getSharedPreferences("offline_download_settings", Context.MODE_PRIVATE)

    fun read(): DownloadSettings = DownloadSettings.fromMap(preferences.all)

    fun write(settings: DownloadSettings) {
        check(preferences.edit()
            .putInt("segments", settings.segments)
            .putInt("parallelDownloads", settings.parallelDownloads)
            .putInt("retryCount", settings.retryCount)
            .putBoolean("unmeteredOnly", settings.unmeteredOnly)
            .commit()) { "Could not save download settings." }
    }
}

/** Changing the limit never interrupts work already in progress. */
internal fun resizeSegmentPool(executor: ThreadPoolExecutor, workers: Int) {
    val size = workers.coerceIn(1, 16)
    if (size > executor.maximumPoolSize) {
        executor.maximumPoolSize = size
        executor.corePoolSize = size
    } else {
        executor.corePoolSize = size
        executor.maximumPoolSize = size
    }
}
