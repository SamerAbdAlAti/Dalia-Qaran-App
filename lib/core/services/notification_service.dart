import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../constants/app_constants.dart';

/// تعريف أصوات التنبيه المتاحة في التطبيق
class PrayerSound {
  final String id;
  final String nameAr;

  /// اسم الملف في android/app/src/main/res/raw/ بدون امتداد
  final String rawFileName;

  /// مسار الملف في assets للمعاينة داخل التطبيق
  final String assetPath;

  const PrayerSound({
    required this.id,
    required this.nameAr,
    required this.rawFileName,
    required this.assetPath,
  });
}

/// قائمة الأصوات المدمجة — أضف ملفات .mp3 في:
///   assets/sounds/  (للمعاينة)
///   android/app/src/main/res/raw/  (للتنبيه)
const List<PrayerSound> kPrayerSounds = [
  PrayerSound(
    id: 'default',
    nameAr: 'نغمة النظام',
    rawFileName: '',
    assetPath: '',
  ),
  PrayerSound(
    id: 'azan_makkah',
    nameAr: 'أذان مكة المكرمة',
    rawFileName: 'azan_makkah',
    assetPath: 'assets/sounds/azan_makkah.mp3',
  ),
  PrayerSound(
    id: 'azan_madinah',
    nameAr: 'أذان المدينة المنورة',
    rawFileName: 'azan_madinah',
    assetPath: 'assets/sounds/azan_madinah.mp3',
  ),
  PrayerSound(
    id: 'azan_egypt',
    nameAr: 'أذان مصري',
    rawFileName: 'azan_egypt',
    assetPath: 'assets/sounds/azan_egypt.mp3',
  ),
  PrayerSound(
    id: 'azan_mishary',
    nameAr: 'مشاري العفاسي',
    rawFileName: 'azan_mishary',
    assetPath: 'assets/sounds/azan_mishary.mp3',
  ),
  PrayerSound(
    id: 'beep_soft',
    nameAr: 'تنبيه هادئ',
    rawFileName: 'beep_soft',
    assetPath: 'assets/sounds/beep_soft.mp3',
  ),
];

// ─── UX: مدة التذكير قبل الصلاة ───
enum ReminderOffset {
  none(0, 'لا تذكير'),
  fiveMin(5, '٥ دقائق قبل'),
  tenMin(10, '١٠ دقائق قبل'),
  fifteenMin(15, '١٥ دقيقة قبل'),
  thirtyMin(30, '٣٠ دقيقة قبل');

  final int minutes;
  final String label;
  const ReminderOffset(this.minutes, this.label);
}

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // ─── Initialization ───

  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    await _createNotificationChannel(soundId: 'default');

    _initialized = true;
  }

  // ─── Channel per sound (Android requires channel per custom sound) ───

  static Future<void> _createNotificationChannel({
    required String soundId,
  }) async {
    final sound = soundId == 'default'
        ? null
        : RawResourceAndroidNotificationSound(
            kPrayerSounds.firstWhere((s) => s.id == soundId).rawFileName,
          );

    final channel = AndroidNotificationChannel(
      soundId == 'default'
          ? AppConstants.notifChannelId
          : '${AppConstants.notifChannelId}_$soundId',
      AppConstants.notifChannelName,
      description: 'تنبيهات أوقات الصلاة',
      importance: Importance.high,
      sound: sound,
      playSound: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // ─── Schedule a single prayer notification ───

  static Future<void> schedulePrayer({
    required int id,
    required String prayerName,
    required DateTime prayerTime,
    required String soundId,
    required ReminderOffset offset,
    required bool vibrate,
  }) async {
    final notifyAt = prayerTime.subtract(Duration(minutes: offset.minutes));
    if (notifyAt.isBefore(DateTime.now())) return;

    final channelId = soundId == 'default'
        ? AppConstants.notifChannelId
        : '${AppConstants.notifChannelId}_$soundId';

    final sound = soundId == 'default'
        ? null
        : RawResourceAndroidNotificationSound(
            kPrayerSounds.firstWhere((s) => s.id == soundId).rawFileName,
          );

    final androidDetails = AndroidNotificationDetails(
      channelId,
      AppConstants.notifChannelName,
      importance: Importance.high,
      priority: Priority.high,
      sound: sound,
      enableVibration: vibrate,
      playSound: true,
      category: AndroidNotificationCategory.alarm,
    );

    final title = offset == ReminderOffset.none
        ? 'حان وقت $prayerName'
        : 'تذكير: $prayerName بعد ${offset.minutes} دقيقة';

    await _plugin.zonedSchedule(
      id,
      title,
      'داليا — أوقات الصلاة',
      tz.TZDateTime.from(notifyAt, tz.local),
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ─── Schedule all 5 prayers for a day ───

  static Future<void> scheduleAllPrayers({
    required Map<String, DateTime> prayerTimes,
    required Map<String, bool> enabledPrayers,
    required String soundId,
    required ReminderOffset offset,
    required bool vibrate,
  }) async {
    await _createNotificationChannel(soundId: soundId);
    await cancelAllPrayers();

    final prayers = {
      'الفجر': (AppConstants.notifFajr, prayerTimes['fajr']),
      'الظهر': (AppConstants.notifDhuhr, prayerTimes['dhuhr']),
      'العصر': (AppConstants.notifAsr, prayerTimes['asr']),
      'المغرب': (AppConstants.notifMaghrib, prayerTimes['maghrib']),
      'العشاء': (AppConstants.notifIsha, prayerTimes['isha']),
    };

    for (final entry in prayers.entries) {
      final name = entry.key;
      final (id, time) = entry.value;
      final enabled = enabledPrayers[name] ?? true;

      if (enabled && time != null) {
        await schedulePrayer(
          id: id,
          prayerName: name,
          prayerTime: time,
          soundId: soundId,
          offset: offset,
          vibrate: vibrate,
        );
      }
    }
  }

  // ─── Cancel ───

  static Future<void> cancelAllPrayers() async {
    for (final id in [
      AppConstants.notifFajr,
      AppConstants.notifDhuhr,
      AppConstants.notifAsr,
      AppConstants.notifMaghrib,
      AppConstants.notifIsha,
    ]) {
      await _plugin.cancel(id);
    }
  }

  // ─── Permission request ───

  static Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  // ─── Battery optimization (UX: يسأل المستخدم مرة واحدة فقط) ───

  static Future<bool> checkExactAlarmPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return await android?.canScheduleExactNotifications() ?? false;
  }
}
