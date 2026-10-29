package dev.beamlak.flixquest_v2.downloads

import android.app.Application
import android.content.Context
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.util.concurrent.CountDownLatch
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30], manifest = Config.NONE, application = Application::class)
class DownloadSettingsTest {
    private val context: Context get() = RuntimeEnvironment.getApplication()

    @Before fun clearSettings() {
        context.getSharedPreferences("offline_download_settings", Context.MODE_PRIVATE)
            .edit().clear().commit()
    }

    @Test fun defaultsAndInvalidValuesAreBounded() {
        assertEquals(DownloadSettings(), DownloadSettings.fromMap(emptyMap<String, Any>()))
        val settings = DownloadSettings.fromMap(
            mapOf("segments" to 500, "parallelDownloads" to -2,
                "retryCount" to 100, "unmeteredOnly" to true),
        )
        assertEquals(16, settings.segments)
        assertEquals(1, settings.parallelDownloads)
        assertEquals(10, settings.retryCount)
        assertTrue(settings.unmeteredOnly)
        assertEquals(8, DownloadSettings.fromMap(mapOf("segments" to "bad")).segments)
    }

    @Test fun preferencesSurviveStoreRecreation() {
        val original = DownloadSettings(12, 3, 9, true)
        DownloadSettingsStore(context).write(original)
        assertEquals(original, DownloadSettingsStore(context).read())
        DownloadSettingsStore(context).write(DownloadSettings())
        assertEquals(DownloadSettings(), DownloadSettingsStore(context).read())
    }

    @Test fun poolResizesWithoutInterruptingRunningSegments() {
        val executor = ThreadPoolExecutor(1, 1, 0L, TimeUnit.MILLISECONDS, LinkedBlockingQueue())
        val started = CountDownLatch(2)
        val release = CountDownLatch(1)
        val finished = CountDownLatch(2)
        try {
            resizeSegmentPool(executor, 2)
            repeat(2) {
                executor.execute {
                    started.countDown()
                    try {
                        release.await()
                    } finally {
                        finished.countDown()
                    }
                }
            }
            assertTrue(started.await(3, TimeUnit.SECONDS))
            resizeSegmentPool(executor, 1)
            assertEquals(1, executor.corePoolSize)
            assertEquals(1, executor.maximumPoolSize)
            assertEquals(2L, finished.count)
            release.countDown()
            assertTrue(finished.await(3, TimeUnit.SECONDS))
            resizeSegmentPool(executor, 999)
            assertEquals(16, executor.maximumPoolSize)
        } finally {
            release.countDown()
            executor.shutdownNow()
        }
    }
}
