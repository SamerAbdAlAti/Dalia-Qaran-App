package app.daliya.quran

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import java.util.Calendar

class DhikrAlarmReceiver : BroadcastReceiver() {

    // ─── Static type definitions ───────────────────────────────────────────────

    data class DhikrInfo(
        val type: String,
        val title: String,
        val body: String,
        val channelPrefix: String,
        val enabledKey: String,
        val intervalKey: String,
        val soundKey: String,
        val defaultSound: String,
        val notifId: Int,       // FIXED — same ID = replaces existing notification
        val requestCode: Int,   // unique per type for AlarmManager
    )

    companion object {
        private const val WINDOW_START_HOUR = 7
        private const val WINDOW_END_HOUR = 21
        private const val WINDOW_END_MIN = 30
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"

        val TYPES = mapOf(
            "istighfar" to DhikrInfo(
                type = "istighfar",
                title = "💚 وقت الاستغفار",
                body = "أستغفر الله العظيم الذي لا إله إلا هو الحي القيوم وأتوب إليه",
                channelPrefix = "dhikr_istighfar",
                enabledKey = "dhikr_istighfar",
                intervalKey = "dhikr_istighfar_interval",
                soundKey = "dhikr_istighfar_sound",
                defaultSound = "dhikr_istighfar",
                notifId = 200,
                requestCode = 10001,
            ),
            "salawat" to DhikrInfo(
                type = "salawat",
                title = "💛 الصلاة على النبي ﷺ",
                body = "اللهم صلِّ وسلِّم وبارك على نبينا محمد ﷺ",
                channelPrefix = "dhikr_salawat",
                enabledKey = "dhikr_salawat",
                intervalKey = "dhikr_salawat_interval",
                soundKey = "dhikr_salawat_sound",
                defaultSound = "dhikr_salawat",
                notifId = 300,
                requestCode = 10002,
            ),
            "tasbih" to DhikrInfo(
                type = "tasbih",
                title = "🤍 وقت التسبيح",
                body = "سبحان الله وبحمده، سبحان الله العظيم",
                channelPrefix = "dhikr_tasbih",
                enabledKey = "dhikr_tasbih",
                intervalKey = "dhikr_tasbih_interval",
                soundKey = "dhikr_tasbih_sound",
                defaultSound = "dhikr_tasbih",
                notifId = 400,
                requestCode = 10003,
            ),
        )

        // ─── Called from MainActivity / BootReceiver ──────────────────────────

        fun scheduleFirst(context: Context, type: String, intervalMinutes: Int) {
            val info = TYPES[type] ?: return
            val fireAt = firstFireTime(intervalMinutes)
            scheduleAt(context, info, fireAt)
        }

        fun cancelType(context: Context, type: String) {
            val info = TYPES[type] ?: return
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = PendingIntent.getBroadcast(
                context, info.requestCode,
                Intent(context, DhikrAlarmReceiver::class.java),
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            )
            if (pi != null) { am.cancel(pi); pi.cancel() }
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(info.notifId)
        }

        // ─── AlarmManager helpers ─────────────────────────────────────────────

        internal fun scheduleAt(context: Context, info: DhikrInfo, fireAt: Long) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, DhikrAlarmReceiver::class.java)
                .putExtra("type", info.type)
            val pi = PendingIntent.getBroadcast(
                context, info.requestCode, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAt, pi)
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, fireAt, pi)
            }
        }

        // First fire: now + interval (clamped to window)
        private fun firstFireTime(intervalMinutes: Int): Long {
            if (intervalMinutes >= 1440) return next9AM()
            val now = System.currentTimeMillis()
            val candidate = now + intervalMinutes * 60_000L
            val endMs = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, WINDOW_END_HOUR)
                set(Calendar.MINUTE, WINDOW_END_MIN)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis
            return if (candidate <= endMs) candidate else nextWindowStart()
        }

        private fun nextWindowStart(): Long = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, WINDOW_START_HOUR)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

        private fun next9AM(): Long {
            val cal = Calendar.getInstance()
            val target = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 9)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            if (cal.after(target)) target.add(Calendar.DAY_OF_YEAR, 1)
            return target.timeInMillis
        }
    }

    // ─── BroadcastReceiver ────────────────────────────────────────────────────

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.MY_PACKAGE_REPLACED",
            "android.intent.action.QUICKBOOT_POWERON" -> {
                rescheduleOnBoot(context)
                return
            }
        }

        val type = intent.getStringExtra("type") ?: return
        val info = TYPES[type] ?: return

        val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val enabled = prefs.getBoolean("flutter.${info.enabledKey}", false)
        if (!enabled) return  // User disabled — stop the chain

        val intervalMinutes = prefs.getLong("flutter.${info.intervalKey}", 60L).toInt()
        val soundId = prefs.getString("flutter.${info.soundKey}", info.defaultSound) ?: info.defaultSound

        showNotification(context, info, soundId)
        scheduleNext(context, info, intervalMinutes)
    }

    // ─── Boot: reschedule all enabled dhikr alarms ────────────────────────────

    private fun rescheduleOnBoot(context: Context) {
        val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        for ((type, info) in TYPES) {
            val enabled = prefs.getBoolean("flutter.${info.enabledKey}", false)
            if (!enabled) continue
            val interval = prefs.getLong("flutter.${info.intervalKey}", 60L).toInt()
            scheduleFirst(context, type, interval)
        }
    }

    // ─── Show notification with FIXED ID (replaces previous of same type) ─────

    private fun showNotification(context: Context, info: DhikrInfo, soundId: String) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "${info.channelPrefix}_$soundId"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && nm.getNotificationChannel(channelId) == null) {
            val soundUri = if (soundId != "default") {
                val resId = context.resources.getIdentifier(soundId, "raw", context.packageName)
                if (resId != 0) Uri.parse("android.resource://${context.packageName}/$resId") else null
            } else null

            val channel = NotificationChannel(channelId, info.title, NotificationManager.IMPORTANCE_HIGH).apply {
                enableVibration(true)
                setVibrationPattern(longArrayOf(0, 300, 200, 300))
                if (soundUri != null) {
                    setSound(soundUri, AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                        .build())
                }
            }
            nm.createNotificationChannel(channel)
        }

        val iconResId = context.resources
            .getIdentifier("ic_notification", "drawable", context.packageName)
            .takeIf { it != 0 } ?: android.R.drawable.ic_popup_reminder

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(iconResId)
            .setContentTitle(info.title)
            .setContentText(info.body)
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText(info.body)
                .setBigContentTitle(info.title))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setTimeoutAfter(60_000)
            .setVibrate(longArrayOf(0, 300, 200, 300))
            .setSubText("داليا")
            .setColor(0xFF1B5E20.toInt())
            .build()

        nm.notify(info.notifId, notification)
    }

    // ─── Self-schedule the next occurrence ────────────────────────────────────

    private fun scheduleNext(context: Context, info: DhikrInfo, intervalMinutes: Int) {
        if (intervalMinutes >= 1440) {
            scheduleAt(context, info, next9AM())
            return
        }

        val cal = Calendar.getInstance()
        val nowMin = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
        val windowEndMin = WINDOW_END_HOUR * 60 + WINDOW_END_MIN
        val nextMin = nowMin + intervalMinutes

        val fireAt = if (nextMin > windowEndMin) {
            nextWindowStart()
        } else {
            System.currentTimeMillis() + intervalMinutes * 60_000L
        }
        scheduleAt(context, info, fireAt)
    }
}
