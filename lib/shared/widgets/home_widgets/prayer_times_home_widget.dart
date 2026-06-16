import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class PrayerTimesHomeWidget extends StatelessWidget {
  final String fajr, dhuhr, asr, maghrib, isha;
  final String nextPrayer, nextPrayerTime;
  final String dateStr;
  final int minutesLeft;

  const PrayerTimesHomeWidget({
    super.key,
    required this.fajr,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.nextPrayer,
    required this.nextPrayerTime,
    required this.dateStr,
    required this.minutesLeft,
  });

  String get _remaining {
    if (minutesLeft <= 0) return 'الآن';
    if (minutesLeft < 60) return 'متبقي $minutesLeft د';
    final h = minutesLeft ~/ 60;
    final m = minutesLeft % 60;
    return m > 0 ? 'متبقي ${h}س ${m}د' : 'متبقي $h ساعة';
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0D2B14);
    const cardBg = Color(0xFF163A1E);
    const accent = AppColors.gold;
    const white = Colors.white;
    const dim = Color(0x88FFFFFF);

    final prayers = [
      ('الفجر', fajr),
      ('الظهر', dhuhr),
      ('العصر', asr),
      ('المغرب', maghrib),
      ('العشاء', isha),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        width: 250,
        height: 110,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: bg,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── Header ───
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('داليا',
                        style: TextStyle(
                            color: accent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                            height: 1.0)),
                    const SizedBox(width: 4),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                          color: accent, shape: BoxShape.circle),
                    ),
                    const Spacer(),
                    Text(dateStr,
                        style: const TextStyle(
                            color: dim,
                            fontSize: 7,
                            fontFamily: 'Cairo',
                            height: 1.0)),
                  ],
                ),

                // ─── Next prayer card ───
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: accent.withValues(alpha: 0.2), width: 0.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Dot indicator
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: const BoxDecoration(
                            color: accent, shape: BoxShape.circle),
                      ),
                      // Prayer name
                      Text(nextPrayer,
                          style: const TextStyle(
                              color: white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              fontFamily: 'Cairo',
                              height: 1.0)),
                      const SizedBox(width: 5),
                      // Time
                      Text(nextPrayerTime,
                          style: const TextStyle(
                              color: accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              fontFamily: 'Cairo',
                              height: 1.0)),
                      const Spacer(),
                      // Remaining badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: accent.withValues(alpha: 0.4), width: 0.5),
                        ),
                        child: Text(
                          _remaining,
                          style: const TextStyle(
                              color: accent,
                              fontSize: 7,
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w700,
                              height: 1.0),
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── 5 prayers row ───
                Row(
                  children: [
                    for (final (name, time) in prayers)
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(name,
                                style: TextStyle(
                                    color: name == nextPrayer
                                        ? accent
                                        : dim,
                                    fontSize: 6,
                                    fontFamily: 'Cairo',
                                    height: 1.0)),
                            const SizedBox(height: 3),
                            Text(time,
                                style: TextStyle(
                                    color: name == nextPrayer
                                        ? accent
                                        : white,
                                    fontSize: 9,
                                    fontWeight: name == nextPrayer
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontFamily: 'Cairo',
                                    height: 1.0)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
