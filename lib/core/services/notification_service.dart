import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../constants/app_constants.dart';
import 'platform_service.dart';

// ─── Available sounds ───

class PrayerSound {
  final String id;
  final String nameAr;
  final String rawFileName; // res/raw/ (empty = system default)
  final String assetPath;  // assets/ (empty = system default)
  final bool isCustom;

  const PrayerSound({
    required this.id,
    required this.nameAr,
    this.rawFileName = '',
    this.assetPath = '',
    this.isCustom = false,
  });
}

const List<PrayerSound> kPrayerSounds = [
  PrayerSound(id: 'default', nameAr: 'نغمة النظام'),
  PrayerSound(
    id: 'azan_makkah',
    nameAr: 'أذان مكة المكرمة',
    rawFileName: 'azan_makkah',
    assetPath: 'assets/sounds/azan/azan_makkah.mp3',
  ),
  PrayerSound(
    id: 'azan_madinah',
    nameAr: 'أذان المدينة المنورة',
    rawFileName: 'azan_madinah',
    assetPath: 'assets/sounds/azan/azan_madinah.mp3',
  ),
  PrayerSound(
    id: 'azan_egypt',
    nameAr: 'أذان مصري',
    rawFileName: 'azan_egypt',
    assetPath: 'assets/sounds/azan/azan_egypt.mp3',
  ),
  PrayerSound(
    id: 'azan_mishary',
    nameAr: 'مشاري العفاسي',
    rawFileName: 'azan_mishary',
    assetPath: 'assets/sounds/azan/azan_mishary.mp3',
  ),
  PrayerSound(
    id: 'beep_soft',
    nameAr: 'تنبيه هادئ',
    rawFileName: 'beep_soft',
    assetPath: 'assets/sounds/azkar/beep_soft.mp3',
  ),
  // مخصص — يُضاف ديناميكياً في الواجهة
  PrayerSound(id: 'custom', nameAr: 'نغمة مخصصة', isCustom: true),
];

// ─── Reminder offset ───

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

// ─── Service ───

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _bgChannelId = 'daliya_background';
  static const _bgChannelName = 'الخدمة في الخلفية';

  static const _downloadChannelId = 'quran_audio_download';
  static const _downloadNotifId = 900;

  // ─── Init ───

  static Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    try {
      final tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {}

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Default channel
    await _createNotificationChannel(soundId: 'default');

    // Background / persistent notification channel (low importance)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _bgChannelId,
          _bgChannelName,
          description: 'إشعار دائم يُبقي التطبيق نشطاً في الخلفية',
          importance: Importance.min,
          playSound: false,
          enableVibration: false,
          showBadge: false,
        ));

    // Download progress channel
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _downloadChannelId,
          'تحميل القرآن الصوتي',
          description: 'تقدم تحميل التلاوات الصوتية',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          showBadge: true,
        ));

    _initialized = true;
  }

  // ─── Channel management ───

  static Future<void> _createNotificationChannel({
    required String soundId,
    String? customSoundUri,
  }) async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    AndroidNotificationSound? sound;
    if (soundId == 'custom' && customSoundUri != null) {
      sound = UriAndroidNotificationSound(customSoundUri);
    } else if (soundId != 'default') {
      final match = kPrayerSounds.where((s) => s.id == soundId).firstOrNull;
      if (match != null && match.rawFileName.isNotEmpty) {
        sound = RawResourceAndroidNotificationSound(match.rawFileName);
      }
    }

    final channelId = _channelIdFor(soundId, customSoundUri);
    await androidPlugin.createNotificationChannel(AndroidNotificationChannel(
      channelId,
      AppConstants.notifChannelName,
      description: 'تنبيهات أوقات الصلاة',
      importance: Importance.high,
      sound: sound,
      playSound: true,
    ));
  }

  static String _channelIdFor(String soundId, String? customUri) {
    if (soundId == 'custom') {
      // channel ID based on hash of URI so different files get different channels
      return '${AppConstants.notifChannelId}_custom_${customUri.hashCode.abs()}';
    }
    if (soundId == 'default') return AppConstants.notifChannelId;
    return '${AppConstants.notifChannelId}_$soundId';
  }

  // ─── Schedule all 5 prayers ───

  static Future<void> scheduleAllPrayers({
    required Map<String, DateTime> prayerTimes,
    required Map<String, bool> enabledPrayers,
    required String soundId,
    required ReminderOffset offset,
    required bool vibrate,
    String? customSoundUri,
    Map<String, DateTime>? tomorrowPrayerTimes,
  }) async {
    await _clearNotificationCache();
    await _createNotificationChannel(
        soundId: soundId, customSoundUri: customSoundUri);
    await cancelAllPrayers();

    // alarmClock mode needs user-granted SCHEDULE_EXACT_ALARM — fall back to
    // inexactAllowWhileIdle (up to 9 min delay) when permission not granted.
    final canExact = await checkExactAlarmPermission();
    final mode = canExact
        ? AndroidScheduleMode.alarmClock
        : AndroidScheduleMode.inexactAllowWhileIdle;

    await _scheduleDay(
      dayPrayerTimes: prayerTimes,
      enabledPrayers: enabledPrayers,
      idOffset: 0,
      soundId: soundId,
      offset: offset,
      vibrate: vibrate,
      customSoundUri: customSoundUri,
      scheduleMode: mode,
    );

    if (tomorrowPrayerTimes != null && tomorrowPrayerTimes.isNotEmpty) {
      await _scheduleDay(
        dayPrayerTimes: tomorrowPrayerTimes,
        enabledPrayers: enabledPrayers,
        idOffset: AppConstants.notifTomorrowOffset,
        soundId: soundId,
        offset: offset,
        vibrate: vibrate,
        customSoundUri: customSoundUri,
        scheduleMode: mode,
      );
    }
  }

  static Future<void> _scheduleDay({
    required Map<String, DateTime> dayPrayerTimes,
    required Map<String, bool> enabledPrayers,
    required int idOffset,
    required String soundId,
    required ReminderOffset offset,
    required bool vibrate,
    String? customSoundUri,
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle,
  }) async {
    final prayers = {
      'الفجر': (AppConstants.notifFajr + idOffset, dayPrayerTimes['الفجر']),
      'الظهر': (AppConstants.notifDhuhr + idOffset, dayPrayerTimes['الظهر']),
      'العصر': (AppConstants.notifAsr + idOffset, dayPrayerTimes['العصر']),
      'المغرب': (AppConstants.notifMaghrib + idOffset, dayPrayerTimes['المغرب']),
      'العشاء': (AppConstants.notifIsha + idOffset, dayPrayerTimes['العشاء']),
    };

    for (final entry in prayers.entries) {
      final name = entry.key;
      final (id, time) = entry.value;
      final enabled = enabledPrayers[name] ?? true;
      if (!enabled || time == null) continue;

      await schedulePrayer(
        id: id,
        prayerName: name,
        prayerTime: time,
        soundId: soundId,
        offset: offset,
        vibrate: vibrate,
        customSoundUri: customSoundUri,
        scheduleMode: scheduleMode,
      );
    }
  }

  // ─── Schedule single prayer ───

  // ─── Prayer-specific Islamic messages ───

  static String _prayerIcon(String name) => switch (name) {
    'الفجر'  => '🌅',
    'الظهر'  => '☀️',
    'العصر'  => '🌤',
    'المغرب' => '🌆',
    'العشاء' => '🌙',
    _         => '🕌',
  };

  static String _prayerBody(String name) => switch (name) {
    'الفجر'  => 'الصلاةُ خيرٌ من النوم — قم وتطهَّر وصلِّ لله',
    'الظهر'  => 'توقَّف وتطهَّر — فريضة الظهر تنتظرك',
    'العصر'  => 'الصلاةُ الوسطى — احرص عليها يحفظك الله',
    'المغرب' => 'بادر إلى المغرب — وقتها قصير فلا تؤخّر',
    'العشاء' => 'اختم يومك بالعشاء — وضع اليد في يد الله',
    _         => 'حان وقت الصلاة',
  };

  static String _reminderBody(String name, int min) =>
    'استعدّ لصلاة $name — تبقّى $min ${min == 5 ? 'دقائق' : 'دقيقة'}';

  static Future<void> schedulePrayer({
    required int id,
    required String prayerName,
    required DateTime prayerTime,
    required String soundId,
    required ReminderOffset offset,
    required bool vibrate,
    String? customSoundUri,
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle,
  }) async {
    final notifyAt = prayerTime.subtract(Duration(minutes: offset.minutes));
    if (notifyAt.isBefore(DateTime.now())) return;

    final channelId = _channelIdFor(soundId, customSoundUri);
    final sound = await _buildSound(soundId, customSoundUri);

    final isReminder = offset != ReminderOffset.none;
    final icon = _prayerIcon(prayerName);
    final title = isReminder
        ? '$icon $prayerName بعد ${offset.minutes} دقيقة'
        : '$icon حان وقت $prayerName';
    final body = isReminder
        ? _reminderBody(prayerName, offset.minutes)
        : _prayerBody(prayerName);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        AppConstants.notifChannelName,
        importance: Importance.high,
        priority: Priority.high,
        sound: sound,
        enableVibration: vibrate,
        playSound: true,
        category: AndroidNotificationCategory.alarm,
        color: const Color(0xFF1B5E20),
        icon: '@drawable/ic_notification',
        subText: 'داليا',
        ticker: title,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: 'داليا • أوقات الصلاة',
          htmlFormatContent: false,
          htmlFormatContentTitle: false,
        ),
      ),
    );
    final scheduledTime = tz.TZDateTime.from(notifyAt, tz.local);

    try {
      await _plugin.zonedSchedule(
        id, title, body, scheduledTime, details,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      await _clearNotificationCache();
      await _plugin.zonedSchedule(
        id, title, body, scheduledTime, details,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  // ─── Cancel prayers ───

  // flutter_local_notifications stores scheduled notifications in a native Android
  // SharedPreferences file named "scheduled_notifications". After a plugin upgrade
  // the serialization format changes, causing "Missing type parameter" on every
  // cancel/schedule call. We clear the native file via a MethodChannel.
  static const _platformChannel = MethodChannel('app.daliya.quran/platform');

  static Future<void> _clearNotificationCache() async {
    try {
      await _platformChannel.invokeMethod('clearNotificationCache');
    } catch (_) {}
  }

  static Future<void> cancelAllPrayers() async {
    final ids = [
      AppConstants.notifFajr,
      AppConstants.notifDhuhr,
      AppConstants.notifAsr,
      AppConstants.notifMaghrib,
      AppConstants.notifIsha,
      AppConstants.notifFajr + AppConstants.notifTomorrowOffset,
      AppConstants.notifDhuhr + AppConstants.notifTomorrowOffset,
      AppConstants.notifAsr + AppConstants.notifTomorrowOffset,
      AppConstants.notifMaghrib + AppConstants.notifTomorrowOffset,
      AppConstants.notifIsha + AppConstants.notifTomorrowOffset,
    ];
    for (final id in ids) {
      try {
        await _plugin.cancel(id);
      } catch (_) {
        await _clearNotificationCache();
        break;
      }
    }
  }

  // ─── Debug: schedule azan every minute ───

  // IDs 800-819 reserved for debug notifications
  static const _debugBaseId = 800;
  static const kDebugCount = 10;

  /// Returns ({scheduled, errors, firstFireAt}) — scheduled = count of successful zonedSchedule calls
  static Future<({int scheduled, List<String> errors, DateTime? firstFireAt})> scheduleDebugTest({
    required String soundId,
    String? customSoundUri,
  }) async {
    // Ensure timezone is ready
    tz.initializeTimeZones();
    try {
      final tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {}

    // Cancel previous debug notifications and recreate the channel fresh
    await _clearNotificationCache();
    for (int i = 0; i < kDebugCount; i++) {
      try { await _plugin.cancel(_debugBaseId + i); } catch (_) {}
    }

    final sound = await _buildSound(soundId, customSoundUri);
    await _recreateDebugChannel(sound); // حذف + إعادة إنشاء لتطبيق الصوت الجديد

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _debugChannelId,
        'اختبار الإشعارات',
        importance: Importance.max,
        priority: Priority.max,
        sound: sound,
        enableVibration: true,
        playSound: true,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        ticker: 'اختبار داليا',
      ),
    );

    int scheduled = 0;
    final errors = <String>[];
    DateTime? firstFireAt;

    for (int i = 0; i < kDebugCount; i++) {
      final fireAt = tz.TZDateTime.now(tz.local).add(Duration(seconds: (i + 1) * 10));
      try {
        await _plugin.zonedSchedule(
          _debugBaseId + i,
          'اختبار الأذان (${i + 1}/$kDebugCount)',
          'داليا — اختبار | ${fireAt.hour}:${fireAt.minute.toString().padLeft(2, '0')}:${fireAt.second.toString().padLeft(2, '0')}',
          fireAt,
          details,
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        firstFireAt ??= fireAt;
        scheduled++;
      } catch (e) {
        errors.add('إشعار ${i + 1}: $e');
      }
    }
    return (scheduled: scheduled, errors: errors, firstFireAt: firstFireAt);
  }

  /// اختبار بـ Dart Timer (يعمل فقط والتطبيق مفتوح — يتجاوز AlarmManager كلياً)
  static Future<void> scheduleDebugDartTimers({
    required String soundId,
    String? customSoundUri,
    required int intervalSeconds,
    required int count,
    required void Function(int fired) onFired,
  }) async {
    final sound = await _buildSound(soundId, customSoundUri);
    await _recreateDebugChannel(sound);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _debugChannelId,
        'اختبار الإشعارات',
        importance: Importance.max,
        priority: Priority.max,
        sound: sound,
        enableVibration: true,
        playSound: true,
        fullScreenIntent: true,
      ),
    );
    for (int i = 0; i < count; i++) {
      Future.delayed(Duration(seconds: (i + 1) * intervalSeconds), () async {
        try {
          await _plugin.show(
            _debugBaseId + i,
            'Dart Timer (${i + 1}/$count)',
            'داليا — Timer Test (بدون AlarmManager)',
            details,
          );
          onFired(i + 1);
        } catch (_) {}
      });
    }
  }

  static Future<int> getDebugPendingCount() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending
        .where((n) => n.id >= _debugBaseId && n.id < _debugBaseId + kDebugCount)
        .length;
  }

  static Future<void> cancelDebugTest() async {
    for (int i = 0; i < kDebugCount; i++) {
      try { await _plugin.cancel(_debugBaseId + i); } catch (_) {}
    }
  }

  // channel مخصص للـ debug — يُحذف ويُعاد إنشاؤه في كل اختبار لتجنب كاش Android
  static const _debugChannelId = 'prayer_times_debug_test';

  static Future<AndroidNotificationSound?> _buildSound(String soundId, String? customSoundUri) async {
    if (soundId == 'custom' && customSoundUri != null) {
      return UriAndroidNotificationSound(customSoundUri);
    }
    if (soundId != 'default') {
      final match = kPrayerSounds.where((s) => s.id == soundId).firstOrNull;
      if (match != null && match.rawFileName.isNotEmpty) {
        return RawResourceAndroidNotificationSound(match.rawFileName);
      }
    }
    return null;
  }

  static Future<void> _recreateDebugChannel(AndroidNotificationSound? sound) async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;
    // حذف الـ channel القديم أولاً حتى تُطبَّق إعدادات الصوت الجديدة
    await androidPlugin.deleteNotificationChannel(_debugChannelId);
    await androidPlugin.createNotificationChannel(AndroidNotificationChannel(
      _debugChannelId,
      'اختبار الإشعارات',
      description: 'channel مؤقت للاختبار',
      importance: Importance.max,
      sound: sound,
      playSound: true,
      enableVibration: true,
    ));
  }

  /// إشعار فوري (بدون جدولة) — يختبر الـ channel والصوت
  static Future<bool> showDebugNow({required String soundId, String? customSoundUri}) async {
    final sound = await _buildSound(soundId, customSoundUri);
    await _recreateDebugChannel(sound);
    try {
      await _plugin.show(
        _debugBaseId + kDebugCount,
        'اختبار فوري — داليا',
        'إذا ظهر هذا الإشعار فالـ channel والصوت يعملان ✓',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _debugChannelId,
            'اختبار الإشعارات',
            importance: Importance.max,
            priority: Priority.max,
            sound: sound,
            enableVibration: true,
            playSound: true,
            fullScreenIntent: true,
          ),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── Immediate show (used by PrayerTimerService Dart timers) ───

  static Future<void> showPrayerNow({
    required String prayerName,
    required String soundId,
    required bool vibrate,
    String? customSoundUri,
  }) async {
    final channelId = _channelIdFor(soundId, customSoundUri);
    final sound = await _buildSound(soundId, customSoundUri);
    final icon = _prayerIcon(prayerName);
    final title = '$icon حان وقت $prayerName';
    final body = _prayerBody(prayerName);
    try {
      await _plugin.show(
        _prayerIdFor(prayerName),
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            AppConstants.notifChannelName,
            importance: Importance.high,
            priority: Priority.high,
            sound: sound,
            enableVibration: vibrate,
            playSound: true,
            category: AndroidNotificationCategory.alarm,
            color: const Color(0xFF1B5E20),
            icon: '@drawable/ic_notification',
            subText: 'داليا',
            ticker: title,
            styleInformation: BigTextStyleInformation(
              body,
              contentTitle: title,
              summaryText: 'داليا • أوقات الصلاة',
            ),
          ),
        ),
      );
    } catch (_) {}
  }

  static Future<void> showReminderNow({
    required String prayerName,
    required int minutesBefore,
    required String soundId,
    required bool vibrate,
    String? customSoundUri,
  }) async {
    final channelId = _channelIdFor(soundId, customSoundUri);
    final sound = await _buildSound(soundId, customSoundUri);
    final icon = _prayerIcon(prayerName);
    final title = '$icon $prayerName بعد $minutesBefore دقيقة';
    final body = _reminderBody(prayerName, minutesBefore);
    try {
      await _plugin.show(
        _reminderIdFor(prayerName),
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            AppConstants.notifChannelName,
            importance: Importance.high,
            priority: Priority.high,
            sound: sound,
            enableVibration: vibrate,
            playSound: true,
            color: const Color(0xFFF9A825),
            icon: '@drawable/ic_notification',
            subText: 'داليا',
            ticker: title,
            styleInformation: BigTextStyleInformation(
              body,
              contentTitle: title,
              summaryText: 'داليا • تذكير بالصلاة',
            ),
          ),
        ),
      );
    } catch (_) {}
  }

  static int _prayerIdFor(String name) => switch (name) {
        'الفجر' => AppConstants.notifFajr,
        'الظهر' => AppConstants.notifDhuhr,
        'العصر' => AppConstants.notifAsr,
        'المغرب' => AppConstants.notifMaghrib,
        _ => AppConstants.notifIsha,
      };

  static int _reminderIdFor(String name) => switch (name) {
        'الفجر' => AppConstants.notifFajrReminder,
        'الظهر' => AppConstants.notifDhuhrReminder,
        'العصر' => AppConstants.notifAsrReminder,
        'المغرب' => AppConstants.notifMaghribReminder,
        _ => AppConstants.notifIshaReminder,
      };

  // ─── Background / persistent notification ───

  static Future<void> showBackgroundServiceNotification() async {
    await _plugin.show(
      AppConstants.notifBackgroundService,
      'داليا نشطة في الخلفية',
      'تنبيهات أوقات الصلاة مفعّلة',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _bgChannelId,
          _bgChannelName,
          importance: Importance.min,
          priority: Priority.min,
          ongoing: true,
          autoCancel: false,
          showWhen: false,
          playSound: false,
          enableVibration: false,
          icon: '@drawable/ic_notification',
        ),
      ),
    );
  }

  static Future<void> cancelBackgroundServiceNotification() async {
    await _plugin.cancel(AppConstants.notifBackgroundService);
  }

  // ─── Custom sound: pick file + copy + get URI ───

  /// يفتح منتقي الملفات، ينسخ الملف داخلياً، يُرجع content URI
  static Future<String?> pickAndSaveCustomSound() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.first;

    // Get bytes (works on both Android scoped storage and direct paths)
    final bytes = picked.bytes;
    if (bytes == null || bytes.isEmpty) return null;

    // Save to internal files/sounds/ directory
    final dir = await getApplicationDocumentsDirectory();
    final soundsDir = Directory('${dir.path}/sounds');
    if (!await soundsDir.exists()) await soundsDir.create(recursive: true);

    final ext = picked.extension?.toLowerCase() ?? 'mp3';
    final destFile = File('${soundsDir.path}/custom_sound.$ext');
    await destFile.writeAsBytes(bytes, flush: true);

    // Get FileProvider content URI via platform channel
    final uri = await PlatformService.getFileProviderUri(destFile.path);
    return uri;
  }

  // ─── Permission ───

  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  static Future<bool> checkExactAlarmPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.canScheduleExactNotifications() ?? false;
  }

  // ─── Download progress notification ───

  static Future<void> showDownloadProgress({
    required String reciterName,
    required int surahNum,
    required int total,
    String surahName = '',
  }) async {
    final percent = ((surahNum / total) * 100).round();
    final body = surahName.isNotEmpty
        ? '$surahName  ($surahNum/$total) — $percent٪'
        : 'سورة $surahNum من $total — $percent٪';
    try {
      await _plugin.show(
        _downloadNotifId,
        '📥 $reciterName',
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _downloadChannelId,
            'تحميل القرآن الصوتي',
            importance: Importance.low,
            priority: Priority.low,
            onlyAlertOnce: true,
            showProgress: true,
            maxProgress: total,
            progress: surahNum,
            ongoing: true,
            autoCancel: false,
            playSound: false,
            enableVibration: false,
            icon: '@drawable/ic_notification',
            subText: 'داليا',
          ),
        ),
      );
    } catch (_) {}
  }

  static Future<void> cancelDownloadNotification() async {
    try {
      await _plugin.cancel(_downloadNotifId);
    } catch (_) {}
  }

  static Future<void> showDownloadComplete({
    required String reciterName,
    int failedCount = 0,
  }) async {
    final title = failedCount == 0 ? '✅ اكتمل التحميل' : '⚠️ اكتمل التحميل مع أخطاء';
    final body  = failedCount == 0
        ? 'تم تحميل $reciterName كاملاً'
        : 'تم تحميل $reciterName — فشل $failedCount سور (أعد المحاولة)';
    try {
      await _plugin.show(
        _downloadNotifId,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _downloadChannelId,
            'تحميل القرآن الصوتي',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            playSound: false,
            enableVibration: false,
            icon: '@drawable/ic_notification',
            subText: 'داليا',
            autoCancel: true,
          ),
        ),
      );
    } catch (_) {}
  }
}
