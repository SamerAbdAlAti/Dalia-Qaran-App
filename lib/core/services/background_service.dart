import 'package:workmanager/workmanager.dart';

/// اسم المهمة الخلفية اليومية لإعادة جدولة الصلوات
const _kDailyRescheduleTask = 'daliya_daily_reschedule';

/// يُستدعى من WorkManager في الخلفية (top-level function — شرط WorkManager)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == _kDailyRescheduleTask) {
      // إعادة جدولة صلوات اليوم — يُنفَّذ في isolate منفصل
      // سيُكتمل عند بناء feature أوقات الصلاة
    }
    return Future.value(true);
  });
}

class BackgroundService {
  static Future<void> init() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  /// جدولة مهمة يومية لإعادة حساب أوقات الصلاة وإعادة الجدولة
  static Future<void> scheduleDailyReschedule() async {
    await Workmanager().registerPeriodicTask(
      _kDailyRescheduleTask,
      _kDailyRescheduleTask,
      // كل 24 ساعة — WorkManager يختار الوقت المناسب لتوفير البطارية
      frequency: const Duration(hours: 24),
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: false,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
  }
}
