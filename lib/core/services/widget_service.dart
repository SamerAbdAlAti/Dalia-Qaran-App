import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../constants/daily_verses.dart';
import '../../shared/widgets/home_widgets/ayah_home_widget.dart';
import '../../shared/widgets/home_widgets/prayer_times_home_widget.dart';
import '../../shared/widgets/home_widgets/qibla_home_widget.dart';

// ١٢ ساعة بأرقام عربية + ص/م — مطابقة لتنسيق الوقت في باقي التطبيق
// (بدل DateFormat('HH:mm') الذي كان يعرض نظام ٢٤ ساعة).
String _formatTime12h(DateTime t) {
  const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  String ar(int n, {bool pad = false}) {
    final s = pad ? n.toString().padLeft(2, '0') : n.toString();
    return s.split('').map((c) => d[int.parse(c)]).join();
  }
  final h = t.hour;
  final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  final period = h < 12 ? 'ص' : 'م';
  return '${ar(displayH)}:${ar(t.minute, pad: true)} $period';
}

class WidgetService {
  static const _prayerWidget = 'PrayerTimesWidget';
  static const _ayahWidget = 'AyahWidget';
  static const _qiblaWidget = 'QiblaWidget';

  static Future<void> init() async {
    await HomeWidget.setAppGroupId('app.daliya.quran');
  }

  // Keys for rendered image paths stored in home_widget SharedPreferences
  static const _keyPrayerImage = 'prayer_times_image';
  static const _keyAyahImage = 'ayah_image';
  static const _keyQiblaImage = 'qibla_image';

  static Future<void> updatePrayerWidget({
    required Map<String, DateTime> prayerTimes,
    required String nextPrayer,
    required DateTime nextPrayerTime,
    required int minutesLeft,
  }) async {
    final dateFmt = DateFormat('EEEE، d MMMM', 'ar');
    try {
      await HomeWidget.renderFlutterWidget(
        PrayerTimesHomeWidget(
          fajr: _formatTime12h(prayerTimes['الفجر'] ?? DateTime.now()),
          dhuhr: _formatTime12h(prayerTimes['الظهر'] ?? DateTime.now()),
          asr: _formatTime12h(prayerTimes['العصر'] ?? DateTime.now()),
          maghrib: _formatTime12h(prayerTimes['المغرب'] ?? DateTime.now()),
          isha: _formatTime12h(prayerTimes['العشاء'] ?? DateTime.now()),
          nextPrayer: nextPrayer,
          nextPrayerTime: _formatTime12h(nextPrayerTime),
          dateStr: dateFmt.format(DateTime.now()),
          minutesLeft: minutesLeft,
        ),
        key: _keyPrayerImage,
        logicalSize: const Size(250, 110),
        pixelRatio: 3.0,
      );
      await HomeWidget.updateWidget(androidName: _prayerWidget);
    } catch (_) {}
  }

  static Future<void> updateAyahWidget({
    required String ayahText,
    required String surahName,
    required int ayahNumber,
  }) async {
    try {
      await HomeWidget.renderFlutterWidget(
        AyahHomeWidget(
          ayahText: ayahText,
          reference: '$surahName — $ayahNumber',
        ),
        key: _keyAyahImage,
        logicalSize: const Size(250, 110),
        pixelRatio: 3.0,
      );
      await HomeWidget.updateWidget(androidName: _ayahWidget);
    } catch (_) {}
  }

  static Future<void> updateTodayAyah() async {
    final idx = DateTime.now().day % dailyVerses.length;
    final (text, surah, num) = dailyVerses[idx];
    await updateAyahWidget(
      ayahText: '﴿ $text ﴾',
      surahName: 'سورة $surah',
      ayahNumber: num,
    );
  }

  static Future<void> updateQiblaWidget({
    required double qiblaAngle,
    required String cityName,
  }) async {
    try {
      await HomeWidget.renderFlutterWidget(
        QiblaHomeWidget(angle: qiblaAngle, cityName: cityName),
        key: _keyQiblaImage,
        logicalSize: const Size(110, 110),
        pixelRatio: 3.0,
      );
      await HomeWidget.updateWidget(androidName: _qiblaWidget);
    } catch (_) {}
  }
}
