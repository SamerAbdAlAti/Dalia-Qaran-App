# WorkManager
-keep class androidx.work.** { *; }
-keep interface androidx.work.** { *; }
-dontwarn androidx.work.**

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
