import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

class WidgetService {
  static const _appGroupId = 'app.daliya.quran';
  static const _prayerWidget = 'PrayerTimesWidget';
  static const _ayahWidget = 'AyahWidget';
  static const _qiblaWidget = 'QiblaWidget';

  static Future<void> init() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  static Future<void> updatePrayerWidget({
    required Map<String, DateTime> prayerTimes,
    required String nextPrayer,
    required DateTime nextPrayerTime,
  }) async {
    final fmt = DateFormat('HH:mm');
    await Future.wait([
      HomeWidget.saveWidgetData('next_prayer_name', nextPrayer),
      HomeWidget.saveWidgetData(
          'next_prayer_time', fmt.format(nextPrayerTime)),
      HomeWidget.saveWidgetData(
          'fajr', fmt.format(prayerTimes['الفجر'] ?? DateTime.now())),
      HomeWidget.saveWidgetData(
          'dhuhr', fmt.format(prayerTimes['الظهر'] ?? DateTime.now())),
      HomeWidget.saveWidgetData(
          'asr', fmt.format(prayerTimes['العصر'] ?? DateTime.now())),
      HomeWidget.saveWidgetData(
          'maghrib', fmt.format(prayerTimes['المغرب'] ?? DateTime.now())),
      HomeWidget.saveWidgetData(
          'isha', fmt.format(prayerTimes['العشاء'] ?? DateTime.now())),
      HomeWidget.saveWidgetData(
          'next_epoch', nextPrayerTime.millisecondsSinceEpoch),
    ]);
    await HomeWidget.updateWidget(
      androidName: _prayerWidget,
    );
  }

  static Future<void> updateAyahWidget({
    required String ayahText,
    required String surahName,
    required int ayahNumber,
  }) async {
    await Future.wait([
      HomeWidget.saveWidgetData('ayah_text', ayahText),
      HomeWidget.saveWidgetData('ayah_ref', '$surahName — $ayahNumber'),
    ]);
    await HomeWidget.updateWidget(androidName: _ayahWidget);
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
      ('إِنَّ الْحَسَنَاتِ يُذْهِبْنَ السَّيِّئَاتِ', 'هود', 114),
      ('فَإِنَّ مَعَ الْعُسْرِ يُسْرًا', 'الشرح', 5),
      ('وَمَا تَفْعَلُوا مِنْ خَيْرٍ يَعْلَمْهُ اللَّهُ', 'البقرة', 197),
      ('وَتَوَكَّلْ عَلَى اللَّهِ وَكَفَىٰ بِاللَّهِ وَكِيلًا', 'الأحزاب', 3),
      ('قُلْ إِنَّ صَلَاتِي وَنُسُكِي وَمَحْيَايَ وَمَمَاتِي لِلَّهِ', 'الأنعام', 162),
      ('وَلَا تَقْنَطُوا مِن رَّحْمَةِ اللَّهِ', 'الزمر', 53),
      ('يَا أَيُّهَا الَّذِينَ آمَنُوا اسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ', 'البقرة', 153),
      ('وَلَا تَحْسَبَنَّ اللَّهَ غَافِلًا عَمَّا يَعْمَلُ الظَّالِمُونَ', 'إبراهيم', 42),
      ('رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً', 'البقرة', 201),
      ('وَاللَّهُ خَيْرُ الرَّازِقِينَ', 'الجمعة', 11),
      ('أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ', 'الرعد', 28),
      ('إِنَّمَا الْمُؤْمِنُونَ إِخْوَةٌ', 'الحجرات', 10),
      ('وَلَا تُفْسِدُوا فِي الْأَرْضِ بَعْدَ إِصْلَاحِهَا', 'الأعراف', 56),
      ('وَقُلِ اعْمَلُوا فَسَيَرَى اللَّهُ عَمَلَكُمْ', 'التوبة', 105),
      ('وَلَنَبْلُوَنَّكُم بِشَيْءٍ مِّنَ الْخَوْفِ وَالْجُوعِ', 'البقرة', 155),
      ('وَبَشِّرِ الصَّابِرِينَ', 'البقرة', 155),
      ('حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ', 'آل عمران', 173),
      ('رَبِّ اشْرَحْ لِي صَدْرِي', 'طه', 25),
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
    await Future.wait([
      HomeWidget.saveWidgetData('qibla_angle', qiblaAngle.round()),
      HomeWidget.saveWidgetData('qibla_city', cityName),
    ]);
    await HomeWidget.updateWidget(androidName: _qiblaWidget);
  }
}
