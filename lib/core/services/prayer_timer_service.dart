import 'dart:async';
import 'notification_service.dart';

// Dart-timer-based prayer notification scheduler.
// Fires immediately via _plugin.show() — no AlarmManager needed.
// Works when the Flutter engine is alive (app open / in recent apps).
// AlarmManager (schedulePrayer) runs in parallel as backup for fully-closed-app.

class PrayerTimerService {
  static final _timers = <Timer>[];

  static void cancelAll() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  static void scheduleToday({
    required Map<String, DateTime> prayerTimes,
    required Map<String, bool> enabledPrayers,
    required String soundId,
    required bool vibrate,
    required int reminderMinutes,
    String? customSoundUri,
  }) {
    cancelAll();
    final now = DateTime.now();

    for (final entry in prayerTimes.entries) {
      if (!(enabledPrayers[entry.key] ?? true)) continue;

      // ─── Prayer notification ───
      final prayerDelay = entry.value.difference(now);
      if (!prayerDelay.isNegative) {
        _timers.add(Timer(prayerDelay, () {
          NotificationService.showPrayerNow(
            prayerName: entry.key,
            soundId: soundId,
            vibrate: vibrate,
            customSoundUri: customSoundUri,
          );
        }));
      }

      // ─── Reminder before prayer ───
      if (reminderMinutes > 0) {
        final reminderTime =
            entry.value.subtract(Duration(minutes: reminderMinutes));
        final reminderDelay = reminderTime.difference(now);
        if (!reminderDelay.isNegative) {
          _timers.add(Timer(reminderDelay, () {
            NotificationService.showReminderNow(
              prayerName: entry.key,
              minutesBefore: reminderMinutes,
              soundId: soundId,
              vibrate: vibrate,
              customSoundUri: customSoundUri,
            );
          }));
        }
      }
    }
  }

  static int get pendingCount => _timers.where((t) => t.isActive).length;
}
