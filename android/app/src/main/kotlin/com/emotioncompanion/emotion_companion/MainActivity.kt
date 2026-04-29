package com.emotioncompanion.emotion_companion

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.emotioncompanion/icon"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "setIcon") {
                    val isNight = call.argument<Boolean>("isNight") ?: false
                    switchIcon(isNight)
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun switchIcon(isNight: Boolean) {
        val packageName = packageName
        val pm = packageManager

        val dayAlias = ComponentName(packageName, "$packageName.MainActivityDay")
        val nightAlias = ComponentName(packageName, "$packageName.MainActivityNight")

        if (isNight) {
            pm.setComponentEnabledSetting(dayAlias,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP)
            pm.setComponentEnabledSetting(nightAlias,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP)
        } else {
            pm.setComponentEnabledSetting(nightAlias,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP)
            pm.setComponentEnabledSetting(dayAlias,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP)
        }
    }
}
