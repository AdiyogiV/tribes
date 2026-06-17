package com.canay.dhaara.widget

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.canay.dhaara.MainActivity
import com.canay.dhaara.R
import java.util.Calendar

/**
 * Persistent lock-screen notification that mirrors the Vedic Date home-screen
 * widget. Android removed the native lock-screen widget API in API 21, so an
 * ongoing low-priority notification with [NotificationCompat.VISIBILITY_PUBLIC]
 * is the closest approximation.
 *
 * Behavior:
 *   • Channel importance LOW → no sound, no vibration, no heads-up.
 *   • setOngoing(true) → user can't swipe it away accidentally.
 *   • Refresh cadence matches the widget tick (60s) so Ghati·Pala stays live.
 *   • Tap → opens HolyCow page (same intent as the widget).
 *
 * Opt-in:
 *   • Controlled by SharedPreferences key `flutter.widget_lockNotifEnabled`
 *     written from Dart via WidgetDataService. Default OFF — a permanent
 *     notification is intrusive and must be explicit.
 */
object VedicDateLockNotification {

    private const val CHANNEL_ID = "vedic_date_lock"
    private const val CHANNEL_NAME = "Vedic Date (Lock screen)"
    private const val CHANNEL_DESC = "Persistent panchang on the lock screen"
    private const val NOTIFICATION_ID = 0x1EDA7E

    /** Pref key controlling whether the notification should be shown. */
    private const val PREF_ENABLED = "flutter.widget_lockNotifEnabled"

    /**
     * Publish or refresh the notification if the user has opted in. If they
     * haven't, ensure any stale notification is cancelled.
     */
    fun refresh(context: Context) {
        val prefs = context.getSharedPreferences(WidgetBuilder.PREFS_FILE, Context.MODE_PRIVATE)
        val enabled = prefs.getBoolean(PREF_ENABLED, false)

        if (!enabled) {
            cancel(context)
            return
        }

        // POST_NOTIFICATIONS is runtime-permission gated on Android 13+. If we
        // don't have it, silently skip — Flutter side requested it via the
        // standard permission plugin already.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                context,
                "android.permission.POST_NOTIFICATIONS"
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) return
        }

        ensureChannel(context)

        val vt = VedicTimeCalculator.calculate(Calendar.getInstance())
        val moon = VedicTimeCalculator.moonPhase(Calendar.getInstance())
        val lunarMonth = prefs.getString("flutter.widget_lunarMonth", null)
        val paksha = prefs.getString("flutter.widget_paksha", null)
        val tithi = prefs.getString("flutter.widget_tithiName", null)
        val numericDate = prefs.getString("flutter.widget_vedicNumericDate", null)

        // Title — moon + month if we have it, otherwise generic.
        val title = buildString {
            append(moon.emoji)
            append("  ")
            append(lunarMonth ?: "Vedic Date")
        }

        // Subtitle — Paksha + Tithi · GhatiPala · Prahar
        val tithiPart = listOfNotNull(paksha, tithi).joinToString(" ")
        val timePart = "G${vt.ghati}·P${String.format("%02d", vt.pala)} · ${vt.praharName}"
        val subtitle = if (tithiPart.isEmpty()) timePart else "$tithiPart  •  $timePart"

        val tapIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("route", "/cosmic")
        }
        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                PendingIntent.FLAG_IMMUTABLE else 0
        val tapPendingIntent = PendingIntent.getActivity(
            context, 1, tapIntent, pendingFlags
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(subtitle)
            .setStyle(
                NotificationCompat.BigTextStyle().bigText(
                    buildString {
                        append(subtitle)
                        if (!numericDate.isNullOrEmpty()) {
                            append('\n').append(numericDate)
                        }
                    }
                )
            )
            .setContentIntent(tapPendingIntent)
            .setOngoing(true)
            .setShowWhen(false)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_STATUS)

        try {
            NotificationManagerCompat.from(context)
                .notify(NOTIFICATION_ID, builder.build())
        } catch (e: SecurityException) {
            // Permission was revoked between our check and notify — ignore.
            android.util.Log.w("VedicLockNotif", "notify() denied", e)
        }
    }

    /** Cancel the notification (e.g., user toggled the preference off). */
    fun cancel(context: Context) {
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = CHANNEL_DESC
            setShowBadge(false)
            enableLights(false)
            enableVibration(false)
            lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
        }
        nm.createNotificationChannel(channel)
    }
}
