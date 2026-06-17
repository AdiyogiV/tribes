package com.canay.dhaara

import android.content.Context
import android.content.res.Configuration
import com.canay.dhaara.widget.VedicDateLockNotification
import com.canay.dhaara.widget.VedicDateWidgetProvider
import com.canay.dhaara.widget.VedicDateWidgetSmallProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    /**
     * Force home-screen widgets to refresh when the system UI mode (light/dark)
     * changes. The launcher caches widget RemoteViews and does NOT automatically
     * re-inflate them on theme change, so qualifier-based resources
     * (drawable-night, values-night) appear stale until we explicitly broadcast
     * an update.
     *
     * Activity receives this callback because the manifest declares
     * `android:configChanges="...|uiMode"`.
     */
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        VedicDateWidgetProvider.refreshAll(this)
        VedicDateWidgetSmallProvider.refreshAll(this)
    }

    /**
     * Refresh on resume so theme changes that occurred while the app was in the
     * background (e.g., user toggled system theme from notification shade) are
     * reflected immediately when they return to the home screen. Also nudges
     * the lock-screen notification in case the user opted in but has no widget
     * placed (which would otherwise mean no tick to refresh it).
     */
    override fun onResume() {
        super.onResume()
        VedicDateWidgetProvider.refreshAll(this)
        VedicDateWidgetSmallProvider.refreshAll(this)
        VedicDateLockNotification.refresh(this)
    }

    /**
     * Method channel that lets Flutter toggle / refresh the persistent
     * lock-screen notification. Dart writes the
     * `flutter.widget_lockNotifEnabled` SharedPreference; we call refresh()
     * here so the change is applied immediately without waiting for the next
     * widget alarm tick.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
                      "com.canay.dhaara/widget").setMethodCallHandler { call, result ->
            when (call.method) {
                "refreshLockNotification" -> {
                    VedicDateLockNotification.refresh(this)
                    result.success(true)
                }
                "cancelLockNotification" -> {
                    VedicDateLockNotification.cancel(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
