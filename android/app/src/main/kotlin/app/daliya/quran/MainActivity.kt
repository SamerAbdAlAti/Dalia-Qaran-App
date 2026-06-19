package app.daliya.quran

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    companion object {
        var mediaChannel: MethodChannel? = null
        const val ACTION_OPEN_PLAYER = "app.daliya.quran.OPEN_PLAYER"
        const val EXTRA_SURAH_NUM = "surahNum"
        private const val CHANNEL_NAME = "app.daliya.quran/platform"
        private const val PLAYER_NOTIF_ID = 999
        private const val PLAYER_CHANNEL_ID = "quran_player_v1"
    }

    private var mediaSession: MediaSessionCompat? = null
    private var pendingOpenSurah: Int = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        // Clear stale flutter_local_notifications SharedPreferences BEFORE Flutter initializes.
        val migrationPrefs = getSharedPreferences("daliya_migration", MODE_PRIVATE)
        val clearedVersion = migrationPrefs.getInt("notifications_cleared_version", 0)
        val currentVersion = try {
            packageManager.getPackageInfo(packageName, 0).versionCode
        } catch (_: Exception) { 0 }
        if (clearedVersion < currentVersion) {
            getSharedPreferences("scheduled_notifications", MODE_PRIVATE).edit().clear().apply()
            migrationPrefs.edit().putInt("notifications_cleared_version", currentVersion).apply()
        }
        super.onCreate(savedInstanceState)
        handleOpenPlayerIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleOpenPlayerIntent(intent)
    }

    private fun handleOpenPlayerIntent(intent: Intent?) {
        if (intent?.action != ACTION_OPEN_PLAYER) return
        val surahNum = intent.getIntExtra(EXTRA_SURAH_NUM, 0)
        if (surahNum <= 0) return
        val ch = mediaChannel
        if (ch != null) {
            ch.invokeMethod("onMediaAction", "open:$surahNum")
        } else {
            pendingOpenSurah = surahNum
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val mc = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        mediaChannel = mc

        // System media surfaces (lock screen, quick-settings media card) drive
        // playback via MediaSession.TransportControls, NOT our notification's
        // own PendingIntents — without this callback those buttons are no-ops.
        mediaSession = MediaSessionCompat(this, "QuranPlayer").also { session ->
            session.setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() { mc.invokeMethod("onMediaAction", "play") }
                override fun onPause() { mc.invokeMethod("onMediaAction", "pause") }
                override fun onSkipToNext() { mc.invokeMethod("onMediaAction", "next") }
                override fun onSkipToPrevious() { mc.invokeMethod("onMediaAction", "prev") }
            })
            session.isActive = true
        }
        createPlayerChannel()

        // Forward any tap that happened before the Dart engine was ready
        if (pendingOpenSurah > 0) {
            mc.invokeMethod("onMediaAction", "open:$pendingOpenSurah")
            pendingOpenSurah = 0
        }

        mc.setMethodCallHandler { call, result ->
            when (call.method) {

                "isBatteryOptimizationIgnored" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    } else {
                        result.success(true)
                    }
                }

                "requestBatteryOptimizationExemption" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                            startActivity(Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                Uri.parse("package:$packageName")
                            ))
                        }
                    }
                    result.success(true)
                }

                "clearNotificationCache" -> {
                    getSharedPreferences("scheduled_notifications", MODE_PRIVATE)
                        .edit().clear().apply()
                    result.success(true)
                }

                "openMiuiAutostart" -> {
                    try {
                        startActivity(Intent().apply {
                            setClassName(
                                "com.miui.securitycenter",
                                "com.miui.permcenter.autostart.AutoStartManagementActivity"
                            )
                        })
                        result.success(true)
                    } catch (_: Exception) {
                        try {
                            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                            })
                            result.success(false)
                        } catch (e2: Exception) {
                            result.error("OPEN_FAILED", e2.message, null)
                        }
                    }
                }

                "getFileProviderUri" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("NULL_PATH", "filePath is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val uri = FileProvider.getUriForFile(
                            this, "$packageName.fileprovider", File(filePath)
                        )
                        result.success(uri.toString())
                    } catch (e: Exception) {
                        result.error("FILE_PROVIDER_ERROR", e.message, null)
                    }
                }

                "scheduleDhikr" -> {
                    val type = call.argument<String>("type")
                    val interval = call.argument<Int>("interval_minutes") ?: 60
                    if (type != null) {
                        DhikrAlarmReceiver.scheduleFirst(this, type, interval)
                        result.success(true)
                    } else {
                        result.error("NO_TYPE", "type is required", null)
                    }
                }

                "cancelDhikr" -> {
                    val type = call.argument<String>("type")
                    if (type != null) {
                        DhikrAlarmReceiver.cancelType(this, type)
                        result.success(true)
                    } else {
                        result.error("NO_TYPE", "type is required", null)
                    }
                }

                "showPlayerNotification" -> {
                    showPlayerNotification(
                        surahName = call.argument<String>("surahName") ?: "",
                        subtitle   = call.argument<String>("subtitle")   ?: "",
                        isPlaying  = call.argument<Boolean>("isPlaying") ?: false,
                        surahNum   = call.argument<Int>("surahNum")      ?: 0,
                    )
                    result.success(null)
                }

                "updatePlayerState" -> {
                    showPlayerNotification(
                        surahName = call.argument<String>("surahName") ?: "",
                        subtitle   = call.argument<String>("subtitle")   ?: "",
                        isPlaying  = call.argument<Boolean>("isPlaying") ?: false,
                        surahNum   = call.argument<Int>("surahNum")      ?: 0,
                    )
                    result.success(null)
                }

                "hidePlayerNotification" -> {
                    hidePlayerNotification()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun createPlayerChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                PLAYER_CHANNEL_ID,
                "مشغل القرآن",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "إشعار التحكم في مشغل القرآن الصوتي"
                setShowBadge(false)
                setSound(null, null)
                enableVibration(false)
            }
            notificationManager.createNotificationChannel(ch)
        }
    }

    private fun showPlayerNotification(
        surahName: String, subtitle: String, isPlaying: Boolean, surahNum: Int
    ) {
        val session = mediaSession ?: return

        session.setMetadata(
            MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, surahName)
                .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, subtitle)
                .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, "القرآن الكريم")
                .build()
        )
        session.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(
                    PlaybackStateCompat.ACTION_PLAY_PAUSE or
                    PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                    PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
                )
                .setState(
                    if (isPlaying) PlaybackStateCompat.STATE_PLAYING
                    else PlaybackStateCompat.STATE_PAUSED,
                    PlaybackStateCompat.PLAYBACK_POSITION_UNKNOWN, 1f
                )
                .build()
        )

        val piFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0

        fun broadcastPI(action: String, reqCode: Int) = PendingIntent.getBroadcast(
            this, reqCode,
            Intent(action).setClass(this, QuranMediaReceiver::class.java),
            piFlags
        )

        val notif = NotificationCompat.Builder(this, PLAYER_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(surahName)
            .setContentText(subtitle)
            .setContentIntent(
                PendingIntent.getActivity(
                    this, 104,
                    Intent(this, MainActivity::class.java).apply {
                        action = ACTION_OPEN_PLAYER
                        putExtra(EXTRA_SURAH_NUM, surahNum)
                        addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    },
                    piFlags
                )
            )
            .setOngoing(true)
            .setAutoCancel(false)
            .setShowWhen(false)
            .setOnlyAlertOnce(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(R.drawable.ic_player_prev, "السابق", broadcastPI(QuranMediaReceiver.ACTION_PREV, 101))
            .addAction(
                if (isPlaying) R.drawable.ic_player_pause else R.drawable.ic_player_play,
                if (isPlaying) "إيقاف" else "تشغيل",
                broadcastPI(if (isPlaying) QuranMediaReceiver.ACTION_PAUSE else QuranMediaReceiver.ACTION_PLAY, 102)
            )
            .addAction(R.drawable.ic_player_next, "التالي", broadcastPI(QuranMediaReceiver.ACTION_NEXT, 103))
            .setStyle(
                androidx.media.app.NotificationCompat.MediaStyle()
                    .setMediaSession(session.sessionToken)
                    .setShowActionsInCompactView(0, 1, 2)
            )
            .build()

        notificationManager.notify(PLAYER_NOTIF_ID, notif)
    }

    private fun hidePlayerNotification() {
        notificationManager.cancel(PLAYER_NOTIF_ID)
        mediaSession?.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setState(PlaybackStateCompat.STATE_NONE, 0, 1f)
                .build()
        )
    }

    private val notificationManager: NotificationManager
        get() = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

    override fun onDestroy() {
        super.onDestroy()
        mediaChannel = null
        mediaSession?.release()
        mediaSession = null
    }
}
