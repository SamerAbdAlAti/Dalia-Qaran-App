# ────────────────────────────────────────────────────────────
# Gson TypeToken — not needed for flutter_local_notifications v19+
# (Gson bumped to 2.12 which handles its own type retention).
# Kept here exactly per the official example for compatibility.
-keepattributes Signature
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

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
