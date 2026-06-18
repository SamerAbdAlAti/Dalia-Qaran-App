package app.daliya.quran

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channel = "app.daliya.quran/platform"

    override fun onCreate(savedInstanceState: Bundle?) {
        // Clear stale flutter_local_notifications SharedPreferences BEFORE Flutter initializes.
        // Old entries serialized with a different Gson TypeToken format cause
        // "Missing type parameter" crashes in loadScheduledNotifications().
        // We clear once per install by checking a version flag.
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
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
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
                                val intent = Intent(
                                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                    Uri.parse("package:$packageName")
                                )
                                startActivity(intent)
                            }
                        }
                        result.success(true)
                    }

                    "clearNotificationCache" -> {
                        // flutter_local_notifications stores scheduled notification JSON
                        // in a named SharedPreferences file called "scheduled_notifications".
                        // Clearing it fixes "Missing type parameter" after plugin upgrades.
                        getSharedPreferences("scheduled_notifications", MODE_PRIVATE)
                            .edit().clear().apply()
                        result.success(true)
                    }

                    "openMiuiAutostart" -> {
                        // MIUI Autostart settings — هذا الـ intent يفتح إعدادات التشغيل التلقائي في MIUI
                        try {
                            val intent = Intent()
                            intent.setClassName(
                                "com.miui.securitycenter",
                                "com.miui.permcenter.autostart.AutoStartManagementActivity"
                            )
                            startActivity(intent)
                            result.success(true)
                        } catch (_: Exception) {
                            // Not MIUI — open general app settings instead
                            try {
                                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                                intent.data = Uri.parse("package:$packageName")
                                startActivity(intent)
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
                            val file = File(filePath)
                            val uri = FileProvider.getUriForFile(
                                this,
                                "$packageName.fileprovider",
                                file
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

                    else -> result.notImplemented()
                }
            }
    }
}
