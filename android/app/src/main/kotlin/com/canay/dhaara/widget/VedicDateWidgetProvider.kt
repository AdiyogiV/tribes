package com.canay.dhaara.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.widget.RemoteViews
import com.canay.dhaara.MainActivity
import com.canay.dhaara.R
import java.util.Calendar

/**
 * Shared builder for Vedic date widget RemoteViews.
 *
 * Both [VedicDateWidgetProvider] (medium 4×2) and
 * [VedicDateWidgetSmallProvider] (small 2×2) delegate here.
 *
 * Data flow:
 *   • Vedic time (Ghati, Pala, Prahar) — computed natively every tick
 *   • Moon phase — computed natively from astronomical formula
 *   • Panchang (Tithi, Paksha, Lunar month) — read from SharedPreferences
 *     written by Flutter via `WidgetDataService`
 *
 * Refresh: AlarmManager fires every 60s so Ghati·Pala stays live.
 * Android's updatePeriodMillis (30 min) is a fallback safety net.
 */
object WidgetBuilder {
    /** SharedPreferences file used by Flutter's shared_preferences plugin. */
    const val PREFS_FILE = "FlutterSharedPreferences"

    // Keys written by Dart WidgetDataService (prefixed with "flutter." per convention)
    private const val KEY_LUNAR_MONTH = "flutter.widget_lunarMonth"
    private const val KEY_PAKSHA = "flutter.widget_paksha"
    private const val KEY_TITHI_NAME = "flutter.widget_tithiName"
    private const val KEY_VEDIC_NUMERIC_DATE = "flutter.widget_vedicNumericDate"

    /** Custom action for our 60-second alarm tick. */
    const val ACTION_TICK = "com.canay.dhaara.widget.ACTION_TICK"

    // ─────────────────────────────────────────────────────────────────
    // MEDIUM (4×2)
    //
    // ┌────────────────────────────────────┐
    // │  🌓  42·15    │   Jyeshtha        │
    // │  Aparanha     │   Krishna         │
    // │               │   Dwitiya         │
    // │               │   A3/2/2/2083     │
    // └────────────────────────────────────┘
    // ─────────────────────────────────────────────────────────────────
    fun buildMedium(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_vedic_date)
        val now = Calendar.getInstance()
        val vt = VedicTimeCalculator.calculate(now)
        val moon = VedicTimeCalculator.moonPhase(now)
        val prefs = context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)

        // — Left column: Moon + Ghati·Pala + Prahar —
        views.setTextViewText(R.id.widget_moon_emoji, moon.emoji)
        views.setTextViewText(
            R.id.widget_ghati_pala,
            "${vt.ghati}·${String.format("%02d", vt.pala)}"
        )
        views.setTextViewText(R.id.widget_prahar_name, vt.praharName)

        // — Right column: Panchang date —
        val lunarMonth = prefs.getString(KEY_LUNAR_MONTH, null)
        val paksha = prefs.getString(KEY_PAKSHA, null)
        val tithiName = prefs.getString(KEY_TITHI_NAME, null)
        val numericDate = prefs.getString(KEY_VEDIC_NUMERIC_DATE, null)

        views.setTextViewText(R.id.widget_lunar_month, lunarMonth ?: "—")
        views.setTextViewText(R.id.widget_paksha, paksha ?: "—")
        views.setTextViewText(R.id.widget_tithi, tithiName ?: "—")
        views.setTextViewText(R.id.widget_numeric_date, numericDate ?: "")

        // Tap → open app to HolyCow page
        views.setOnClickPendingIntent(R.id.widget_root, launchIntent(context))

        return views
    }

    // ─────────────────────────────────────────────────────────────────
    // SMALL (2×2) — compact date card
    //
    // ┌────────────────┐
    // │ 🌓 Jyeshtha    │
    // │   Krishna      │
    // │   Navami       │
    // │   3/2/9/2083   │
    // │   G42 · P15    │
    // └────────────────┘
    // ─────────────────────────────────────────────────────────────────
    fun buildSmall(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_vedic_date_small)
        val now = Calendar.getInstance()
        val vt = VedicTimeCalculator.calculate(now)
        val moon = VedicTimeCalculator.moonPhase(now)
        val prefs = context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)

        val lunarMonth = prefs.getString(KEY_LUNAR_MONTH, null)
        val paksha = prefs.getString(KEY_PAKSHA, null)
        val tithiName = prefs.getString(KEY_TITHI_NAME, null)
        val numericDate = prefs.getString(KEY_VEDIC_NUMERIC_DATE, null)

        views.setTextViewText(
            R.id.widget_small_header,
            "${moon.emoji} ${lunarMonth ?: "Vedic Date"}"
        )
        views.setTextViewText(R.id.widget_small_paksha, paksha ?: "—")
        views.setTextViewText(R.id.widget_small_tithi, tithiName ?: "—")
        views.setTextViewText(R.id.widget_small_numeric, numericDate ?: "")
        views.setTextViewText(
            R.id.widget_small_time,
            "G${vt.ghati} · P${vt.pala}"
        )

        views.setOnClickPendingIntent(R.id.widget_small_root, launchIntent(context))

        return views
    }

    private fun launchIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("route", "/cosmic")
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        return PendingIntent.getActivity(context, 0, intent, flags)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Alarm-based tick logic shared by both providers
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private object WidgetAlarm {
    private const val TICK_INTERVAL_MS = 60_000L  // 1 minute

    /** Schedule repeating alarm that fires ACTION_TICK to [providerClass]. */
    fun start(context: Context, providerClass: Class<out AppWidgetProvider>) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.setRepeating(
            AlarmManager.ELAPSED_REALTIME,
            SystemClock.elapsedRealtime() + TICK_INTERVAL_MS,
            TICK_INTERVAL_MS,
            tickPendingIntent(context, providerClass)
        )
    }

    /** Cancel the repeating alarm for [providerClass]. */
    fun stop(context: Context, providerClass: Class<out AppWidgetProvider>) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(tickPendingIntent(context, providerClass))
    }

    private fun tickPendingIntent(
        context: Context,
        providerClass: Class<out AppWidgetProvider>
    ): PendingIntent {
        val intent = Intent(context, providerClass).apply {
            action = WidgetBuilder.ACTION_TICK
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        return PendingIntent.getBroadcast(context, 0, intent, flags)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Widget Providers
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/** Medium (4×2) widget — full Vedic date card. */
class VedicDateWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == WidgetBuilder.ACTION_TICK) {
            // Alarm tick — refresh all medium widgets
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, VedicDateWidgetProvider::class.java)
            )
            for (id in ids) {
                try {
                    manager.updateAppWidget(id, WidgetBuilder.buildMedium(context))
                } catch (e: Exception) {
                    android.util.Log.e("VedicWidget", "Tick failed for medium $id", e)
                }
            }
            // Piggyback the lock-screen notification on the same cadence so
            // Ghati·Pala stays live there without a separate alarm.
            VedicDateLockNotification.refresh(context)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            try {
                appWidgetManager.updateAppWidget(id, WidgetBuilder.buildMedium(context))
            } catch (e: Exception) {
                android.util.Log.e("VedicWidget", "Failed to update medium widget $id", e)
            }
        }
        VedicDateLockNotification.refresh(context)
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        WidgetAlarm.start(context, VedicDateWidgetProvider::class.java)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        WidgetAlarm.stop(context, VedicDateWidgetProvider::class.java)
    }

    companion object {
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, VedicDateWidgetProvider::class.java)
            )
            if (ids.isNotEmpty()) {
                val intent = Intent(context, VedicDateWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                }
                context.sendBroadcast(intent)
            }
        }
    }
}

/** Small (2×2) widget — compact Vedic date card. */
class VedicDateWidgetSmallProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == WidgetBuilder.ACTION_TICK) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, VedicDateWidgetSmallProvider::class.java)
            )
            for (id in ids) {
                try {
                    manager.updateAppWidget(id, WidgetBuilder.buildSmall(context))
                } catch (e: Exception) {
                    android.util.Log.e("VedicWidget", "Tick failed for small $id", e)
                }
            }
            VedicDateLockNotification.refresh(context)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            try {
                appWidgetManager.updateAppWidget(id, WidgetBuilder.buildSmall(context))
            } catch (e: Exception) {
                android.util.Log.e("VedicWidget", "Failed to update small widget $id", e)
            }
        }
        VedicDateLockNotification.refresh(context)
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        WidgetAlarm.start(context, VedicDateWidgetSmallProvider::class.java)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        WidgetAlarm.stop(context, VedicDateWidgetSmallProvider::class.java)
    }

    companion object {
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, VedicDateWidgetSmallProvider::class.java)
            )
            if (ids.isNotEmpty()) {
                val intent = Intent(context, VedicDateWidgetSmallProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                }
                context.sendBroadcast(intent)
            }
        }
    }
}
