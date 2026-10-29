package dev.beamlak.flixquest_v2.downloads

import android.app.Application
import android.content.Context
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30], manifest = Config.NONE, application = Application::class)
class PublicDownloadDestinationTest {
    private val context: Context get() = RuntimeEnvironment.getApplication()

    @Before fun clear() {
        context.getSharedPreferences("fastflix_public_downloads", Context.MODE_PRIVATE).edit().clear().commit()
    }

    @Test fun organizesMoviesAndEpisodesWithoutPathTraversal() {
        val movie = JSONObject().put("title", "My / Film").put("mediaType", "movie").put("contentId", 42)
        assertEquals(listOf("FlixQuest", "Movies"), PublicDownloadNames.folder(movie))
        assertEquals("My _ Film (42).mp4", PublicDownloadNames.fileName(movie))
        val episode = JSONObject().put("title", "हिंदी शो").put("mediaType", "episode")
            .put("contentId", 7).put("seasonNumber", 2).put("episodeNumber", 5)
        assertEquals(listOf("FlixQuest", "Series", "हिंदी शो (7)"), PublicDownloadNames.folder(episode))
        assertEquals("S02E05.mp4", PublicDownloadNames.fileName(episode))
        assertEquals("Video", PublicDownloadNames.safe("..."))
        assertFalse(PublicDownloadNames.safe("../unsafe").contains('/'))
    }

    @Test fun destinationAndFailureSurviveRecreation() {
        val preferences = PublicDownloadSettings(context)
        assertTrue(preferences.locationMap()["isDefault"] as Boolean)
        preferences.setTreeUri("content://example/tree/123")
        preferences.setStatus("movie_42", "failed", "storage full")
        val restored = PublicDownloadSettings(context)
        assertEquals("content://example/tree/123", restored.treeUri())
        assertEquals("failed", restored.status("movie_42"))
        assertEquals("storage full", restored.error("movie_42"))
        restored.clear("movie_42")
        assertNull(restored.status("movie_42"))
    }
}
