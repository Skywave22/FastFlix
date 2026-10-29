package dev.beamlak.flixquest_v2.downloads

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.offline.Download
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.ForegroundInfo
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import dev.beamlak.flixquest_v2.R
import java.io.File
import java.io.IOException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** A durable, separately reported public copy of the private offline stream. */
@UnstableApi
class PublicDownloadWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        val id = inputData.getString("id") ?: return Result.failure()
        // A WorkManager restart can be the first entry into this process. The
        // Media3 manager must be created on its application (main) looper.
        val storeReady = CountDownLatch(1)
        var initializedStore: StreamDownloadStore? = null
        Handler(Looper.getMainLooper()).post {
            try { initializedStore = StreamDownloadStore.get(applicationContext) }
            catch (_: Exception) { /* WorkManager can retry initialization. */ }
            finally { storeReady.countDown() }
        }
        storeReady.await()
        val store = initializedStore ?: return Result.retry()
        val settings = PublicDownloadSettings(applicationContext)
        try {
            setForegroundAsync(foregroundInfo()).get()
            if (isStopped) return Result.success()
            val download = store.getDownload(id)
            if (download == null || download.state != Download.STATE_COMPLETED) return Result.success()
            settings.setStatus(id, "saving")
            val metadata = StreamDownloadStore.requestMetadata(download.request)
            val tree = inputData.getString("treeOverride") ?: metadata.optString("publicTreeUri")
            val latch = CountDownLatch(1)
            var exported: kotlin.Result<File>? = null
            Handler(Looper.getMainLooper()).post {
                if (isStopped) latch.countDown() else store.exporter.export(id) {
                    exported = it
                    latch.countDown()
                }
            }
            while (!latch.await(1, TimeUnit.SECONDS)) {
                if (isStopped) return Result.success()
            }
            if (isStopped) return Result.success()
            val file = exported?.getOrThrow() ?: throw IOException("Video export was interrupted.")
            val destination = PublicDownloadDestination(applicationContext).copy(file, metadata, tree) {
                isStopped || settings.status(id) == null ||
                    store.getDownload(id)?.state != Download.STATE_COMPLETED
            }
            if (!isStopped && settings.status(id) != null &&
                store.getDownload(id)?.state == Download.STATE_COMPLETED) {
                settings.setStatus(id, "saved", uri = destination)
            }
        } catch (error: Exception) {
            if (!isStopped && settings.status(id) != null && store.getDownload(id) != null) {
                settings.setStatus(id, "failed", error.message ?: "Could not save a public copy.")
            }
        }
        // The offline download remains usable even when remuxing or copying is
        // unsupported. A visible Retry button schedules a fresh attempt.
        return Result.success()
    }

    private fun foregroundInfo(): ForegroundInfo {
        val manager = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(NotificationChannel(
                CHANNEL, "FlixQuest video copies", NotificationManager.IMPORTANCE_LOW,
            ))
        }
        val notification = NotificationCompat.Builder(applicationContext, CHANNEL)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("Saving video to your download folder")
            .setContentText("Preparing a playable FlixQuest copy")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setProgress(0, 0, true)
            .build()
        val id = 5_000 + (inputData.getString("id").orEmpty().hashCode() and 0x0fffffff)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ForegroundInfo(id, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else ForegroundInfo(id, notification)
    }

    companion object {
        private const val CHANNEL = "fastflix_public_exports"
        private fun workName(id: String) = "fastflix-public-copy:$id"

        fun schedule(context: Context, id: String, retry: Boolean = false) {
            val settings = PublicDownloadSettings(context)
            val state = settings.status(id)
            if (!retry && state in listOf("saved", "failed")) return
            val input = Data.Builder().putString("id", id)
                // A retry uses the current location, so a revoked permission or
                // full drive can be fixed without re-downloading the stream.
                .apply { if (retry) putString("treeOverride", settings.treeUri()) }
                .build()
            val request = OneTimeWorkRequest.Builder(PublicDownloadWorker::class.java).setInputData(input).build()
            if (retry || state == null) settings.setStatus(id, "queued")
            WorkManager.getInstance(context).enqueueUniqueWork(
                workName(id),
                if (retry) ExistingWorkPolicy.REPLACE else ExistingWorkPolicy.KEEP,
                request,
            )
        }

        fun cancel(context: Context, id: String) {
            WorkManager.getInstance(context).cancelUniqueWork(workName(id))
            PublicDownloadSettings(context).clear(id)
        }
    }
}
