import 'package:flutter/services.dart';
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

// ─── Dhikr reminder definitions ───

const _dhikrReminders = [
  ReminderDef(
    id: AppConstants.notifDhikrIstighfar,
    titleAr: '💚 وقت الاستغفار',
    bodyAr: 'أستغفر الله العظيم الذي لا إله إلا هو الحي القيوم وأتوب إليه',
    channelId: 'dhikr_istighfar',
    channelNameAr: 'تذكير الاستغفار',
  ),
  ReminderDef(
    id: AppConstants.notifDhikrSalawat,
    titleAr: '💛 الصلاة على النبي ﷺ',
    bodyAr: 'اللهم صلِّ وسلِّم وبارك على نبينا محمد ﷺ',
    channelId: 'dhikr_salawat',
    channelNameAr: 'تذكير الصلاة على النبي',
  ),
  ReminderDef(
    id: AppConstants.notifDhikrTasbih,
    titleAr: '🤍 وقت التسبيح',
    bodyAr: 'سبحان الله وبحمده، سبحان الله العظيم',
    channelId: 'dhikr_tasbih',
    channelNameAr: 'تذكير التسبيح',
  ),
  ReminderDef(
    id: AppConstants.notifDhikrPostPrayer,
    titleAr: '🕌 أذكار ما بعد الصلاة',
    bodyAr: 'لا تنسَ: سبحان الله ٣٣، الحمد لله ٣٣، الله أكبر ٣٣',
    channelId: 'dhikr_post_prayer',
    channelNameAr: 'أذكار بعد الصلاة',
  ),
];

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

  static Future<AndroidScheduleMode> _resolveMode() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final canExact = await android?.canScheduleExactNotifications() ?? false;
    return canExact
        ? AndroidScheduleMode.alarmClock
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  static const _platformChannel = MethodChannel('app.daliya.quran/platform');

  static Future<void> _clearNotificationCache() async {
    try {
      await _platformChannel.invokeMethod('clearNotificationCache');
    } catch (_) {}
  }

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
        color: const Color(0xFF1B5E20),
        icon: 'ic_notification',
        subText: 'داليا',
        styleInformation: BigTextStyleInformation(
          r.bodyAr,
          contentTitle: r.titleAr,
          summaryText: 'داليا • تذكيرات',
        ),
      );

  // ─── Schedule daily reminder at fixed time ───
  static Future<void> scheduleDailyAt({
    required ReminderDef reminder,
    required int hour,
    required int minute,
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle,
  }) async {
    await _ensureChannel(reminder);
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    final details = NotificationDetails(android: _androidDetails(reminder));
    try {
      await _plugin.zonedSchedule(
        reminder.id,
        reminder.titleAr,
        reminder.bodyAr,
        scheduled,
        details,
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      try {
        await _clearNotificationCache();
        await _plugin.zonedSchedule(
          reminder.id,
          reminder.titleAr,
          reminder.bodyAr,
          scheduled,
          details,
          androidScheduleMode: scheduleMode,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (_) {}
    }
  }

  // ─── Schedule at computed DateTime (qiyam, fajr sunnah) ───
  static Future<void> scheduleOnce({
    required ReminderDef reminder,
    required DateTime at,
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle,
  }) async {
    if (at.isBefore(DateTime.now())) return;
    await _ensureChannel(reminder);
    final details = NotificationDetails(android: _androidDetails(reminder));
    final scheduledTime = tz.TZDateTime.from(at, tz.local);
    try {
      await _plugin.zonedSchedule(
        reminder.id,
        reminder.titleAr,
        reminder.bodyAr,
        scheduledTime,
        details,
        androidScheduleMode: scheduleMode,
      );
    } catch (_) {
      try {
        await _clearNotificationCache();
        await _plugin.zonedSchedule(
          reminder.id,
          reminder.titleAr,
          reminder.bodyAr,
          scheduledTime,
          details,
          androidScheduleMode: scheduleMode,
        );
      } catch (_) {}
    }
  }

  static Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (_) {
      await _clearNotificationCache();
    }
  }

  static Future<void> cancelAll() async {
    for (final r in _reminders) {
      try {
        await _plugin.cancel(r.id);
      } catch (_) {
        await _clearNotificationCache();
        break;
      }
    }
  }

  // ─── Dhikr interval scheduling ───

  static Future<void> _ensureDhikrChannel(String channelId, String channelName, String soundId) async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    AndroidNotificationSound? sound;
    if (soundId != 'default' && soundId.isNotEmpty) {
      sound = RawResourceAndroidNotificationSound(soundId);
    }
    await android?.createNotificationChannel(AndroidNotificationChannel(
      '${channelId}_$soundId',
      channelName,
      importance: Importance.high,
      playSound: true,
      sound: sound,
    ));
  }

  static AndroidNotificationDetails _dhikrAndroidDetails(
      ReminderDef r, String soundId) {
    AndroidNotificationSound? sound;
    if (soundId != 'default' && soundId.isNotEmpty) {
      sound = RawResourceAndroidNotificationSound(soundId);
    }
    return AndroidNotificationDetails(
      '${r.channelId}_$soundId',
      r.channelNameAr,
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      sound: sound,
      color: const Color(0xFF1B5E20),
      icon: 'ic_notification',
      subText: 'داليا',
      ticker: r.titleAr,
      autoCancel: true,
      groupKey: 'daliya_dhikr_${r.channelId}',
      setAsGroupSummary: false,
      styleInformation: BigTextStyleInformation(
        r.bodyAr,
        contentTitle: r.titleAr,
        summaryText: 'داليا • تذكيرات الذكر',
        htmlFormatContent: false,
        htmlFormatContentTitle: false,
      ),
    );
  }

  // intervalMinutes: 30/60/120/180/360 = interval; 1440 = once daily at 9 AM
  // Window: 7:00 AM – 9:30 PM (لا نزعج المستخدم بعد ذلك)
  // offsetSeconds: stagger between dhikr types (0 / 15 / 30) so they don't all fire at once
  static Future<void> _scheduleDhikrInterval({
    required ReminderDef reminder,
    required int intervalMinutes,
    required String soundId,
    required int idBase,
    int offsetSeconds = 0,
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle,
  }) async {
    await _ensureDhikrChannel(reminder.channelId, reminder.channelNameAr, soundId);
    final details = NotificationDetails(android: _dhikrAndroidDetails(reminder, soundId));

    const startMin = 7 * 60;   // 7:00 AM
    const endMin   = 21 * 60 + 30; // 9:30 PM

    final now = tz.TZDateTime.now(tz.local);
    final nowMin = now.hour * 60 + now.minute;
    // Start from next minute when inside window so no slot falls in the past.
    final slotStart = (nowMin >= startMin && nowMin < endMin) ? nowMin + 1 : startMin;

    final List<int> slots = intervalMinutes >= 1440
        ? [9 * 60] // مرة يومياً: 9 صباحاً
        : [
            for (int m = slotStart; m <= endMin; m += intervalMinutes) m,
          ];

    for (int i = 0; i < slots.length && i < AppConstants.notifDhikrSlotCount; i++) {
      final hour   = slots[i] ~/ 60;
      final minute = slots[i] % 60;
      var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute, 0)
          .add(Duration(seconds: offsetSeconds));
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      try {
        await _plugin.zonedSchedule(
          idBase + i,
          reminder.titleAr,
          reminder.bodyAr,
          scheduled,
          details,
          androidScheduleMode: scheduleMode,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (_) {
        try {
          await _clearNotificationCache();
          await _plugin.zonedSchedule(
            idBase + i,
            reminder.titleAr,
            reminder.bodyAr,
            scheduled,
            details,
            androidScheduleMode: scheduleMode,
            matchDateTimeComponents: DateTimeComponents.time,
          );
        } catch (_) {}
      }
    }
  }

  static Future<void> _cancelDhikrSlots(int idBase) async {
    for (int i = 0; i < AppConstants.notifDhikrSlotCount; i++) {
      try { await _plugin.cancel(idBase + i); } catch (_) {}
    }
  }

  static Future<void> scheduleDhikrAll({
    required Map<String, dynamic> prefs,
  }) async {
    // ─── clear corrupted cache first (prevents "Missing type parameter" crash) ───
    await _clearNotificationCache();
    final mode = await _resolveMode();

    // ─── cancel legacy single-shot IDs (migration) ───
    for (final id in [
      AppConstants.notifDhikrIstighfar,
      AppConstants.notifDhikrSalawat,
      AppConstants.notifDhikrTasbih,
      AppConstants.notifDhikrIstighfar + 100,
      AppConstants.notifDhikrSalawat + 100,
      AppConstants.notifDhikrTasbih + 100,
      AppConstants.notifDhikrPostPrayer,
    ]) {
      try { await _plugin.cancel(id); } catch (_) {}
    }

    // ─── استغفار (offset=0) ───
    await _cancelDhikrSlots(AppConstants.notifDhikrIstighfarBase);
    if (prefs[AppConstants.keyDhikrIstighfar] == true) {
      final interval = (prefs[AppConstants.keyDhikrIstighfarInterval] as int?) ?? 60;
      final sound = (prefs[AppConstants.keyDhikrIstighfarSound] as String?) ?? 'dhikr_istighfar';
      final r = _dhikrReminders.firstWhere((d) => d.id == AppConstants.notifDhikrIstighfar);
      try {
        await _scheduleDhikrInterval(
          reminder: r, intervalMinutes: interval, soundId: sound,
          idBase: AppConstants.notifDhikrIstighfarBase, scheduleMode: mode,
          offsetSeconds: 0,
        );
      } catch (_) {}
    }

    // ─── صلاة على النبي ﷺ (offset=1) ───
    await _cancelDhikrSlots(AppConstants.notifDhikrSalawatBase);
    if (prefs[AppConstants.keyDhikrSalawat] == true) {
      final interval = (prefs[AppConstants.keyDhikrSalawatInterval] as int?) ?? 60;
      final sound = (prefs[AppConstants.keyDhikrSalawatSound] as String?) ?? 'dhikr_salawat';
      final r = _dhikrReminders.firstWhere((d) => d.id == AppConstants.notifDhikrSalawat);
      try {
        await _scheduleDhikrInterval(
          reminder: r, intervalMinutes: interval, soundId: sound,
          idBase: AppConstants.notifDhikrSalawatBase, scheduleMode: mode,
          offsetSeconds: 15,
        );
      } catch (_) {}
    }

    // ─── تسبيح (offset=2) ───
    await _cancelDhikrSlots(AppConstants.notifDhikrTasbihBase);
    if (prefs[AppConstants.keyDhikrTasbih] == true) {
      final interval = (prefs[AppConstants.keyDhikrTasbihInterval] as int?) ?? 60;
      final sound = (prefs[AppConstants.keyDhikrTasbihSound] as String?) ?? 'dhikr_tasbih';
      final r = _dhikrReminders.firstWhere((d) => d.id == AppConstants.notifDhikrTasbih);
      try {
        await _scheduleDhikrInterval(
          reminder: r, intervalMinutes: interval, soundId: sound,
          idBase: AppConstants.notifDhikrTasbihBase, scheduleMode: mode,
          offsetSeconds: 30,
        );
      } catch (_) {}
    }
  }

  static List<ReminderDef> get dhikrDefs => _dhikrReminders;

  static Future<void> showDhikrNow({
    required ReminderDef reminder,
    required String soundId,
  }) async {
    await _ensureDhikrChannel(reminder.channelId, reminder.channelNameAr, soundId);
    try {
      await _plugin.show(
        reminder.id,
        reminder.titleAr,
        reminder.bodyAr,
        NotificationDetails(android: _dhikrAndroidDetails(reminder, soundId)),
      );
    } catch (_) {}
  }

  // ─── Public accessor for reminder definitions ───
  static List<ReminderDef> get all => _reminders;
  static ReminderDef byId(int id) => _reminders.firstWhere((r) => r.id == id);

  // Returns (hour, minute) relative to a base prayer time + offset.
  // Falls back to (fallbackH, fallbackM) when base is null (no location yet).
  static (int, int) _prayerRelativeTime(
      DateTime? base, int offsetMin, int fallbackH, int fallbackM) {
    if (base == null) return (fallbackH, fallbackM);
    final t = base.add(Duration(minutes: offsetMin));
    return (t.hour, t.minute);
  }

  // ─── Schedule all enabled reminders from prayer times ───
  static Future<void> scheduleAll({
    required Map<String, dynamic> prefs,
    DateTime? fajrTime,
    DateTime? sunriseTime,
    DateTime? dhuhrTime,
    DateTime? asrTime,
    DateTime? maghribTime,
    DateTime? ishaTime,
  }) async {
    await _clearNotificationCache();
    final mode = await _resolveMode();

    // أذكار الصباح — ١٥ دقيقة بعد الفجر
    if (prefs[AppConstants.keyReminderAdhkarMorning] == true) {
      final (h, m) = _prayerRelativeTime(fajrTime, 15, 6, 15);
      await scheduleDailyAt(
          reminder: byId(AppConstants.notifAdhkarMorning),
          hour: h, minute: m, scheduleMode: mode);
    } else {
      await cancel(AppConstants.notifAdhkarMorning);
    }

    // أذكار المساء — ١٥ دقيقة بعد العصر
    if (prefs[AppConstants.keyReminderAdhkarEvening] == true) {
      final (h, m) = _prayerRelativeTime(asrTime, 15, 16, 15);
      await scheduleDailyAt(
          reminder: byId(AppConstants.notifAdhkarEvening),
          hour: h, minute: m, scheduleMode: mode);
    } else {
      await cancel(AppConstants.notifAdhkarEvening);
    }

    // سنة الفجر القبلية
    if (prefs[AppConstants.keyReminderFajrSunnah] == true && fajrTime != null) {
      final minBefore = prefs[AppConstants.keyReminderFajrSunnahMin] as int? ?? 20;
      await scheduleOnce(
          reminder: byId(AppConstants.notifFajrSunnah),
          at: fajrTime.subtract(Duration(minutes: minBefore)),
          scheduleMode: mode);
    } else {
      await cancel(AppConstants.notifFajrSunnah);
    }

    // قيام الليل — الثلث الأخير من الليل
    if (prefs[AppConstants.keyReminderQiyam] == true &&
        ishaTime != null &&
        fajrTime != null) {
      final qiyamTime = _calcQiyam(ishaTime, fajrTime);
      await scheduleOnce(
          reminder: byId(AppConstants.notifQiyamLayl),
          at: qiyamTime, scheduleMode: mode);
    } else {
      await cancel(AppConstants.notifQiyamLayl);
    }

    // صلاة الضحى — ٢٠ دقيقة بعد الشروق
    if (prefs[AppConstants.keyReminderDuha] == true) {
      final (h, m) = _prayerRelativeTime(sunriseTime, 20, 9, 0);
      await scheduleDailyAt(
          reminder: byId(AppConstants.notifDuha),
          hour: h, minute: m, scheduleMode: mode);
    } else {
      await cancel(AppConstants.notifDuha);
    }

    // تلاوة القرآن — ٣٠ دقيقة بعد المغرب
    if (prefs[AppConstants.keyReminderQuran] == true) {
      final (h, m) = _prayerRelativeTime(maghribTime, 30, 20, 0);
      await scheduleDailyAt(
          reminder: byId(AppConstants.notifQuranReading),
          hour: h, minute: m, scheduleMode: mode);
    } else {
      await cancel(AppConstants.notifQuranReading);
    }

    // الصلاة على النبي ﷺ — ١٥ دقيقة بعد الظهر
    if (prefs[AppConstants.keyReminderSalahAnnabi] == true) {
      final (h, m) = _prayerRelativeTime(dhuhrTime, 15, 12, 15);
      await scheduleDailyAt(
          reminder: byId(AppConstants.notifSalahAnnabi),
          hour: h, minute: m, scheduleMode: mode);
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

}
