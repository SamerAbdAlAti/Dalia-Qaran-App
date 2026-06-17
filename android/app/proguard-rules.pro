# ────────────────────────────────────────────────────────────
# Gson TypeToken — CRITICAL: preserve generic type signatures.
# Flutter enables isMinifyEnabled=true for release builds via
# FlutterPlugin.kt:216 using proguard-android-optimize.txt,
# which strips Signature attributes. Without them, Gson's
# anonymous TypeToken<ArrayList<NotificationDetails>>() {} in
# FlutterLocalNotificationsPlugin.loadScheduledNotifications()
# throws RuntimeException("Missing type parameter.") at every
# call to zonedSchedule (even when SharedPreferences is empty,
# because the TypeToken is instantiated before the null-check).
-keepattributes Signature
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# flutter_local_notifications — keep all plugin classes
-keep class com.dexterous.** { *; }
-keep interface com.dexterous.** { *; }
-keepclassmembers class com.dexterous.** { *; }

# WorkManager — keep all worker classes (callbackDispatcher runs as a Worker)
-keep class androidx.work.** { *; }
-keep interface androidx.work.** { *; }
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.ListenableWorker { *; }
-keep class * extends androidx.work.CoroutineWorker { *; }
-dontwarn androidx.work.**

# Flutter WorkManager plugin (dart entry point must not be renamed/stripped)
-keep class be.tramckrijte.workmanager.** { *; }
-dontwarn be.tramckrijte.workmanager.**

# Dart @pragma('vm:entry-point') — tells R8 these classes are called reflectively
-keep @interface kotlin.Metadata
-keepattributes *Annotation*

# Room
-keep class androidx.room.** { *; }
-keep interface androidx.room.** { *; }
-keep @androidx.room.* class * { *; }
-keep @androidx.room.* interface * { *; }
-dontwarn androidx.room.**

# ObjectBox (if used with R8)
-keep class io.objectbox.** { *; }
-keep interface io.objectbox.** { *; }
-dontwarn io.objectbox.**

# Keep database constructors (critical for WorkManager and Room)
-keep class androidx.work.impl.WorkDatabase_Impl { 
    <init>(...);
}
-keep class * extends androidx.room.RoomDatabase { 
    <init>(...);
}
