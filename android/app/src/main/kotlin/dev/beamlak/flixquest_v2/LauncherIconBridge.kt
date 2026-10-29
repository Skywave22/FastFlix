package dev.beamlak.flixquest_v2

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Changes launcher aliases while leaving the real activity and links intact. */
class LauncherIconBridge(context: Context, messenger: BinaryMessenger) {
    private val appContext = context.applicationContext
    private val channel = MethodChannel(messenger, "dev.beamlak.flixquest_v2/branding")
    private val aliases = mapOf(
        "original" to "dev.beamlak.flixquest_v2.FlixQuestOriginalIcon",
        "play" to "dev.beamlak.flixquest_v2.FastFlixPlayIcon",
        "wing" to "dev.beamlak.flixquest_v2.FastFlixWingIcon",
        "f" to "dev.beamlak.flixquest_v2.FastFlixFIcon",
    )

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "setLogo") {
                result.notImplemented()
            } else {
                val name = aliases[call.argument<String>("logo")]
                if (name == null) {
                    result.error("INVALID_LOGO", "Unknown FlixQuest logo.", null)
                } else {
                    try {
                        select(name)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("LOGO_UPDATE_FAILED", error.message, null)
                    }
                }
            }
        }
    }

    private fun select(selected: String) {
        val manager = appContext.packageManager
        val components = aliases.values.map { ComponentName(appContext, it) }
        val previous = components.associateWith(manager::getComponentEnabledSetting)
        val enabled = PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        val disabled = PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        val flag = PackageManager.DONT_KILL_APP
        if (Build.VERSION.SDK_INT >= 33) {
            manager.setComponentEnabledSettings(components.map {
                PackageManager.ComponentEnabledSetting(
                    it, if (it.className == selected) enabled else disabled, flag,
                )
            })
            return
        }
        try {
            // Enable the replacement first so a launcher is always available.
            manager.setComponentEnabledSetting(
                ComponentName(appContext, selected), enabled, flag,
            )
            components.filter { it.className != selected }.forEach {
                manager.setComponentEnabledSetting(it, disabled, flag)
            }
        } catch (error: Exception) {
            previous.forEach { (component, state) ->
                runCatching { manager.setComponentEnabledSetting(component, state, flag) }
            }
            throw error
        }
    }

    fun dispose() = channel.setMethodCallHandler(null)
}
