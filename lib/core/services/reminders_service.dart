import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../constants/app_constants.dart';

// ─── Reminder definition ───

class ReminderDef {
  final int id;
  final String titleAr;
  final String bodyAr;
  final String channelId;
  final String channelNameAr;

  const ReminderDef({
    required this.id,
    required this.titleAr,
    required this.bodyAr,
    required this.channelId,
    required this.channelNameAr,
  });
}

const _reminders = [
  ReminderDef(
    id: AppConstants.notifAdhkarMorning,
    titleAr: '🌅 أذكار الصباح',
    bodyAr: 'لا تنسَ أذكار الصباح — ابدأ يومك بذكر الله',
    channelId: 'adhkar_morning',
    channelNameAr: 'أذكار الصباح',
  ),
  ReminderDef(
    id: AppConstants.notifAdhkarEvening,
    titleAr: '🌆 أذكار المساء',
    bodyAr: 'حان وقت أذكار المساء — احرص على ختم يومك بذكر الله',
    channelId: 'adhkar_evening',
    channelNameAr: 'أذكار المساء',
  ),
  ReminderDef(
    id: AppConstants.notifFajrSunnah,
    titleAr: '🕌 سنة الفجر القبلية',
    bodyAr: 'قيام الله ويصلي — تهجد قبل صلاة الفجر',
    channelId: 'fajr_sunnah',
    channelNameAr: 'سنة الفجر القبلية',
  ),
  ReminderDef(
    id: AppConstants.notifQiyamLayl,
    titleAr: '🌙 قيام الليل',
    bodyAr: 'ينزل ربنا إلى السماء الدنيا — وقت القيام',
    channelId: 'qiyam_layl',
    channelNameAr: 'قيام الليل',
  ),
  ReminderDef(
    id: AppConstants.notifDuha,
    titleAr: '☀️ صلاة الضحى',
    bodyAr: 'ركعتا الضحى كالنافلة — لا تفوّت أجرها',
    channelId: 'duha',
    channelNameAr: 'صلاة الضحى',
  ),
  ReminderDef(
    id: AppConstants.notifQuranReading,
    titleAr: '📖 تلاوة القرآن',
    bodyAr: 'اقرأ ولو آية — خير من أن يمرّ اليوم بلا تلاوة',
    channelId: 'quran_reading',
    channelNameAr: 'تلاوة القرآن',
  ),
  ReminderDef(
    id: AppConstants.notifSalahAnnabi,
    titleAr: '🤲 الصلاة على النبي ﷺ',
    bodyAr: 'اللهم صلِّ وسلم على نبينا محمد',
    channelId: 'salah_annabi',
    channelNameAr: 'الصلاة على النبي',
  ),
];

// ─── Service ───

class RemindersService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> _ensureChannel(ReminderDef r) async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(AndroidNotificationChannel(
      r.channelId,
      r.channelNameAr,
      importance: Importance.high,
      playSound: true,
    ));
  }

  static AndroidNotificationDetails _androidDetails(ReminderDef r) =>
      AndroidNotificationDetails(
        r.channelId,
        r.channelNameAr,
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
      );

  // ─── Schedule daily reminder at fixed time ───
  static Future<void> scheduleDailyAt({
    required ReminderDef reminder,
    required int hour,
    required int minute,
  }) async {
    await _ensureChannel(reminder);
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      reminder.id,
      reminder.titleAr,
      reminder.bodyAr,
      scheduled,
      NotificationDetails(android: _androidDetails(reminder)),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ─── Schedule at computed DateTime (qiyam, fajr sunnah) ───
  static Future<void> scheduleOnce({
    required ReminderDef reminder,
    required DateTime at,
  }) async {
    if (at.isBefore(DateTime.now())) return;
    await _ensureChannel(reminder);
    await _plugin.zonedSchedule(
      reminder.id,
      reminder.titleAr,
      reminder.bodyAr,
      tz.TZDateTime.from(at, tz.local),
      NotificationDetails(android: _androidDetails(reminder)),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  static Future<void> cancelAll() async {
    for (final r in _reminders) {
      await _plugin.cancel(r.id);
    }
  }

  // ─── Public accessor for reminder definitions ───
  static List<ReminderDef> get all => _reminders;
  static ReminderDef byId(int id) => _reminders.firstWhere((r) => r.id == id);

  // ─── Schedule all enabled reminders from prefs ───
  // prayerFajr / prayerIsha required to compute qiyam & fajr sunnah
  static Future<void> scheduleAll({
    required Map<String, dynamic> prefs,
    DateTime? fajrTime,
    DateTime? ishaTime,
  }) async {
    // أذكار الصباح
    if (prefs[AppConstants.keyReminderAdhkarMorning] == true) {
      final parts = _parseTime(prefs[AppConstants.keyReminderAdhkarMorningTime], 6, 0);
      await scheduleDailyAt(
          reminder: byId(AppConstants.notifAdhkarMorning),
          hour: parts.$1,
          minute: parts.$2);
    } else {
      await cancel(AppConstants.notifAdhkarMorning);
    }

    // أذكار المساء
    if (prefs[AppConstants.keyReminderAdhkarEvening] == true) {
      final parts = _parseTime(prefs[AppConstants.keyReminderAdhkarEveningTime], 16, 0);
      await scheduleDailyAt(
          reminder: byId(AppConstants.notifAdhkarEvening),
          hour: parts.$1,
          minute: parts.$2);
    } else {
      await cancel(AppConstants.notifAdhkarEvening);
    }

    // سنة الفجر القبلية
    if (prefs[AppConstants.keyReminderFajrSunnah] == true && fajrTime != null) {
      final minBefore = prefs[AppConstants.keyReminderFajrSunnahMin] as int? ?? 20;
      await scheduleOnce(
          reminder: byId(AppConstants.notifFajrSunnah),
          at: fajrTime.subtract(Duration(minutes: minBefore)));
    } else {
      await cancel(AppConstants.notifFajrSunnah);
    }

    // قيام الليل — الثلث الأخير من الليل
    if (prefs[AppConstants.keyReminderQiyam] == true &&
        ishaTime != null &&
        fajrTime != null) {
      final qiyamTime = _calcQiyam(ishaTime, fajrTime);
      await scheduleOnce(
          reminder: byId(AppConstants.notifQiyamLayl), at: qiyamTime);
    } else {
      await cancel(AppConstants.notifQiyamLayl);
    }

    // صلاة الضحى
    if (prefs[AppConstants.keyReminderDuha] == true) {
      final parts = _parseTime(prefs[AppConstants.keyReminderDuhaTime], 9, 0);
      await scheduleDailyAt(
          reminder: byId(AppConstants.notifDuha),
          hour: parts.$1,
          minute: parts.$2);
    } else {
      await cancel(AppConstants.notifDuha);
    }

    // تلاوة القرآن
    if (prefs[AppConstants.keyReminderQuran] == true) {
      final parts = _parseTime(prefs[AppConstants.keyReminderQuranTime], 20, 0);
      await scheduleDailyAt(
          reminder: byId(AppConstants.notifQuranReading),
          hour: parts.$1,
          minute: parts.$2);
    } else {
      await cancel(AppConstants.notifQuranReading);
    }

    // الصلاة على النبي ﷺ
    if (prefs[AppConstants.keyReminderSalahAnnabi] == true) {
      final parts = _parseTime(prefs[AppConstants.keyReminderSalahAnnabiTime], 12, 0);
      await scheduleDailyAt(
          reminder: byId(AppConstants.notifSalahAnnabi),
          hour: parts.$1,
          minute: parts.$2);
    } else {
      await cancel(AppConstants.notifSalahAnnabi);
    }
  }

  // ─── Helpers ───

  // Calculates start of last third of night between isha and next fajr
  static DateTime _calcQiyam(DateTime isha, DateTime fajr) {
    // If fajr is before isha (same day), shift fajr to next day
    var nextFajr = fajr;
    if (nextFajr.isBefore(isha)) {
      nextFajr = nextFajr.add(const Duration(days: 1));
    }
    final nightDuration = nextFajr.difference(isha);
    // Last third starts at 2/3 of the night
    return isha.add(Duration(seconds: (nightDuration.inSeconds * 2 / 3).round()));
  }

  // Parse "HH:MM" string or fall back to defaults
  static (int, int) _parseTime(dynamic raw, int defaultH, int defaultM) {
    if (raw is String && raw.contains(':')) {
      final parts = raw.split(':');
      return (int.tryParse(parts[0]) ?? defaultH, int.tryParse(parts[1]) ?? defaultM);
    }
    return (defaultH, defaultM);
  }
}
