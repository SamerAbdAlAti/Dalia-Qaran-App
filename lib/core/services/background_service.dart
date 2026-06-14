import 'package:adhan/adhan.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz_local;
import 'package:workmanager/workmanager.dart';
import '../constants/app_constants.dart';
import 'notification_service.dart';

const _kDailyRescheduleTask = 'daliya_daily_reschedule';

/// يُستدعى من WorkManager في isolate منفصل — يعيد جدولة الصلوات يومياً
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != _kDailyRescheduleTask) return true;
    try {
      tz.initializeTimeZones();
      try {
        final tzName = await FlutterTimezone.getLocalTimezone();
        tz_local.setLocalLocation(tz_local.getLocation(tzName));
      } catch (_) {}
      await NotificationService.init();

      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(AppConstants.keyLatitude);
      final lng = prefs.getDouble(AppConstants.keyLongitude);
      if (lat == null || lng == null) return true;

      final times = _calcPrayers(lat, lng, prefs);

      final soundId = prefs.getString(AppConstants.keyNotifSound) ?? 'default';
      final reminderMin = prefs.getInt(AppConstants.keyNotifReminderMin) ?? 0;
      final vibrate = prefs.getBool(AppConstants.keyNotifVibrate) ?? true;
      final customSoundUri = prefs.getString(AppConstants.keyCustomSoundUri);
      final offset = ReminderOffset.values.firstWhere(
        (r) => r.minutes == reminderMin,
        orElse: () => ReminderOffset.none,
      );

      await NotificationService.scheduleAllPrayers(
        prayerTimes: times,
        enabledPrayers: {
          'الفجر': prefs.getBool(AppConstants.keyNotifyFajr) ?? true,
          'الظهر': prefs.getBool(AppConstants.keyNotifyDhuhr) ?? true,
          'العصر': prefs.getBool(AppConstants.keyNotifyAsr) ?? true,
          'المغرب': prefs.getBool(AppConstants.keyNotifyMaghrib) ?? true,
          'العشاء': prefs.getBool(AppConstants.keyNotifyIsha) ?? true,
        },
        soundId: soundId,
        offset: offset,
        vibrate: vibrate,
        customSoundUri: customSoundUri,
      );
    } catch (_) {}
    return true;
  });
}

Map<String, DateTime> _calcPrayers(
    double lat, double lng, SharedPreferences prefs) {
  final coords = Coordinates(lat, lng);
  final method = prefs.getString(AppConstants.keyCalcMethod) ?? 'egyptian';
  final params = _paramsFor(method);
  final times = PrayerTimes.today(coords, params);
  return {
    'الفجر': times.fajr,
    'الظهر': times.dhuhr,
    'العصر': times.asr,
    'المغرب': times.maghrib,
    'العشاء': times.isha,
  };
}

CalculationParameters _paramsFor(String method) {
  switch (method) {
    case 'muslim_world_league':
      return CalculationMethod.muslim_world_league.getParameters();
    case 'karachi':
      return CalculationMethod.karachi.getParameters();
    case 'umm_al_qura':
      return CalculationMethod.umm_al_qura.getParameters();
    case 'kuwait':
      return CalculationMethod.kuwait.getParameters();
    case 'qatar':
      return CalculationMethod.qatar.getParameters();
    case 'dubai':
      return CalculationMethod.dubai.getParameters();
    case 'moon_sighting_committee':
      return CalculationMethod.moon_sighting_committee.getParameters();
    default:
      return CalculationMethod.egyptian.getParameters().withMethodAdjustments(
            PrayerAdjustments(
                fajr: 1, sunrise: 0, dhuhr: 1, asr: 0, maghrib: 2, isha: -2),
          );
  }
}

class BackgroundService {
  static Future<void> init() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  static Future<void> scheduleDailyReschedule() async {
    await Workmanager().registerPeriodicTask(
      _kDailyRescheduleTask,
      _kDailyRescheduleTask,
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
