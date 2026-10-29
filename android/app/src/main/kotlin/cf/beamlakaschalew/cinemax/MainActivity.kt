package dev.beamlak.flixquest_v2

import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import dev.beamlak.flixquest_v2.downloads.StreamDownloadsBridge
import dev.beamlak.flixquest_v2.downloads.StreamOfflinePlayerFactory
import dev.beamlak.flixquest_v2.links.MediaLinkBridge
import dev.beamlak.flixquest_v2.playback.StreamingDndBridge

class MainActivity: FlutterActivity() {
    private var downloadsBridge: StreamDownloadsBridge? = null
    private var linkBridge: MediaLinkBridge? = null
    private var streamingDndBridge: StreamingDndBridge? = null
    private var launcherIconBridge: LauncherIconBridge? = null

    // Starting an activity of our own (a file picker or external player) also
    // reports the user as leaving, which would send a playing video into picture in picture.
    private var launchingOwnActivity = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        streamingDndBridge = StreamingDndBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        launcherIconBridge = LauncherIconBridge(this, flutterEngine.dartExecutor.binaryMessenger)

        val bridge = StreamDownloadsBridge(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        downloadsBridge = bridge
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "dev.beamlak.flixquest/offline_player",
                StreamOfflinePlayerFactory(bridge.store),
            )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_PRESENTATION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isTelevision" -> result.success(isTelevision())
                else -> result.notImplemented()
            }
        }

        // The intent the activity started on is where a tapped or shared address arrives, and it is
        // already in hand by the time the engine is configured — well before Dart can ask for it.
        linkBridge = MediaLinkBridge(flutterEngine.dartExecutor.binaryMessenger).also {
            it.onIntent(intent)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        linkBridge?.onIntent(intent)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        downloadsBridge?.dispose()
        downloadsBridge = null
        launcherIconBridge?.dispose()
        launcherIconBridge = null
        streamingDndBridge?.dispose()
        streamingDndBridge = null
        linkBridge?.dispose()
        linkBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun startActivityForResult(intent: Intent, requestCode: Int, options: Bundle?) {
        launchingOwnActivity = true
        try {
            super.startActivityForResult(intent, requestCode, options)
        } catch (e: RuntimeException) {
            launchingOwnActivity = false
            throw e
        }
    }

    // Only a real departure, such as the home button, reaches the plugins listening for it.
    override fun onUserLeaveHint() {
        if (launchingOwnActivity) {
            launchingOwnActivity = false
            return
        }
        super.onUserLeaveHint()
    }

    override fun onResume() {
        super.onResume()
        launchingOwnActivity = false
        streamingDndBridge?.setForeground(true)
    }

    override fun onPause() {
        streamingDndBridge?.setForeground(false)
        super.onPause()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (downloadsBridge?.onRequestPermissionsResult(requestCode) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (downloadsBridge?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun isTelevision(): Boolean {
        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
        return uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
            (uiModeManager == null &&
                packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK))
    }

    private companion object {
        const val DEVICE_PRESENTATION_CHANNEL =
            "dev.beamlak.flixquest/device_presentation"
    }
}
