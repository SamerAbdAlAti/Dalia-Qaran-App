import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../../shared/widgets/home_widgets/ayah_home_widget.dart';
import '../../shared/widgets/home_widgets/prayer_times_home_widget.dart';
import '../../shared/widgets/home_widgets/qibla_home_widget.dart';

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
    final fmt = DateFormat('HH:mm');
    final dateFmt = DateFormat('EEEE، d MMMM', 'ar');
    try {
      await HomeWidget.renderFlutterWidget(
        PrayerTimesHomeWidget(
          fajr: fmt.format(prayerTimes['الفجر'] ?? DateTime.now()),
          dhuhr: fmt.format(prayerTimes['الظهر'] ?? DateTime.now()),
          asr: fmt.format(prayerTimes['العصر'] ?? DateTime.now()),
          maghrib: fmt.format(prayerTimes['المغرب'] ?? DateTime.now()),
          isha: fmt.format(prayerTimes['العشاء'] ?? DateTime.now()),
          nextPrayer: nextPrayer,
          nextPrayerTime: fmt.format(nextPrayerTime),
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
    const verses = [
      ('وَنُنَزِّلُ مِنَ الْقُرْآنِ مَا هُوَ شِفَاءٌ وَرَحْمَةٌ لِّلْمُؤْمِنِينَ', 'الإسراء', 82),
      ('إِنَّ مَعَ الْعُسْرِ يُسْرًا', 'الشرح', 6),
      ('وَاللَّهُ يُحِبُّ الصَّابِرِينَ', 'آل عمران', 146),
      ('وَمَن يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ', 'الطلاق', 3),
      ('اللَّهُ نُورُ السَّمَاوَاتِ وَالْأَرْضِ', 'النور', 35),
      ('فَاذْكُرُونِي أَذْكُرْكُمْ', 'البقرة', 152),
      ('وَلَا تَيْأَسُوا مِن رَّوْحِ اللَّهِ', 'يوسف', 87),
      ('وَقُل رَّبِّ زِدْنِي عِلْمًا', 'طه', 114),
      ('إِنَّ اللَّهَ مَعَ الصَّابِرِينَ', 'البقرة', 153),
      ('وَهُوَ مَعَكُمْ أَيْنَ مَا كُنتُمْ', 'الحديد', 4),
      ('وَبِالْوَالِدَيْنِ إِحْسَانًا', 'البقرة', 83),
      ('إِنَّ اللَّهَ غَفُورٌ رَّحِيمٌ', 'البقرة', 173),
      ('وَلَذِكْرُ اللَّهِ أَكْبَرُ', 'العنكبوت', 45),
      ('إِنَّ الْحَسَنَاتِ يُذْهِبْنَ السَّيِّئَاتِي', 'هود', 114),
      ('فَإِنَّ مَعَ الْعُسْرِ يُسْرًا', 'الشرح', 5),
      ('وَمَا تَفْعَلُوا مِنْ خَيْرٍ يَعْلَمْهُ اللَّهُ', 'البقرة', 197),
      ('وَتَوَكَّلْ عَلَى اللَّهِ وَكَفَىٰ بِاللَّهِ وَكِيلًا', 'الأحزاب', 3),
      ('حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ', 'آل عمران', 173),
      ('وَلَا تَقْنَطُوا مِن رَّحْمَةِ اللَّهِ', 'الزمر', 53),
      ('يَا أَيُّهَا الَّذِينَ آمَنُوا اسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ', 'البقرة', 153),
      ('رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً', 'البقرة', 201),
      ('وَاللَّهُ خَيْرُ الرَّازِقِينَ', 'الجمعة', 11),
      ('أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ', 'الرعد', 28),
      ('إِنَّمَا الْمُؤْمِنُونَ إِخْوَةٌ', 'الحجرات', 10),
      ('وَقُلِ اعْمَلُوا فَسَيَرَى اللَّهُ عَمَلَكُمْ', 'التوبة', 105),
      ('وَبَشِّرِ الصَّابِرِينَ', 'البقرة', 155),
      ('حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ', 'آل عمران', 173),
      ('رَبِّ اشْرَحْ لِي صَدْرِي', 'طه', 25),
      ('وَلَا تَحْسَبَنَّ اللَّهَ غَافِلًا عَمَّا يَعْمَلُ الظَّالِمُونَ', 'إبراهيم', 42),
      ('وَلَذِكْرُ اللَّهِ أَكْبَرُ', 'العنكبوت', 45),
      ('وَلَنَبْلُوَنَّكُم بِشَيْءٍ مِّنَ الْخَوْفِ وَالْجُوعِ', 'البقرة', 155),
    ];
    final idx = DateTime.now().day % verses.length;
    final (text, surah, num) = verses[idx];
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
