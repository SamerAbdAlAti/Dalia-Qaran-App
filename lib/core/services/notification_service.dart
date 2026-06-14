import 'dart:io';
import 'package:file_picker/file_picker.dart';
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
  }) async {
    await _createNotificationChannel(
        soundId: soundId, customSoundUri: customSoundUri);
    await cancelAllPrayers();

    final prayers = {
      'الفجر': (AppConstants.notifFajr, prayerTimes['الفجر']),
      'الظهر': (AppConstants.notifDhuhr, prayerTimes['الظهر']),
      'العصر': (AppConstants.notifAsr, prayerTimes['العصر']),
      'المغرب': (AppConstants.notifMaghrib, prayerTimes['المغرب']),
      'العشاء': (AppConstants.notifIsha, prayerTimes['العشاء']),
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
      );
    }
  }

  // ─── Schedule single prayer ───

  static Future<void> schedulePrayer({
    required int id,
    required String prayerName,
    required DateTime prayerTime,
    required String soundId,
    required ReminderOffset offset,
    required bool vibrate,
    String? customSoundUri,
  }) async {
    final notifyAt = prayerTime.subtract(Duration(minutes: offset.minutes));
    if (notifyAt.isBefore(DateTime.now())) return;

    final channelId = _channelIdFor(soundId, customSoundUri);

    AndroidNotificationSound? sound;
    if (soundId == 'custom' && customSoundUri != null) {
      sound = UriAndroidNotificationSound(customSoundUri);
    } else if (soundId != 'default') {
      final match = kPrayerSounds.where((s) => s.id == soundId).firstOrNull;
      if (match != null && match.rawFileName.isNotEmpty) {
        sound = RawResourceAndroidNotificationSound(match.rawFileName);
      }
    }

    final title = offset == ReminderOffset.none
        ? 'حان وقت $prayerName'
        : 'تذكير: $prayerName بعد ${offset.minutes} دقيقة';

    await _plugin.zonedSchedule(
      id,
      title,
      'داليا — أوقات الصلاة',
      tz.TZDateTime.from(notifyAt, tz.local),
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
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ─── Cancel prayers ───

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
          icon: '@mipmap/ic_launcher',
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
}
