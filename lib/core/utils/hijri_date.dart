import 'arabic_utils.dart';

const _hijriMonths = [
  'محرم', 'صفر', 'ربيع الأول', 'ربيع الثاني',
  'جمادى الأولى', 'جمادى الآخرة', 'رجب', 'شعبان',
  'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
];

class HijriDate {
  static ({int day, int month, int year}) fromGregorian(DateTime date) {
    final y = date.year;
    final m = date.month;
    final d = date.day;

    final a = (14 - m) ~/ 12;
    final yr = y + 4800 - a;
    final mo = m + 12 * a - 3;

    final jd = d +
        (153 * mo + 2) ~/ 5 +
        365 * yr +
        yr ~/ 4 -
        yr ~/ 100 +
        yr ~/ 400 -
        32045;

    final l = jd - 1948440 + 10632;
    final n = (l - 1) ~/ 10631;
    final l1 = l - 10631 * n + 354;
    final j = ((10985 - l1) ~/ 5316) * ((50 * l1) ~/ 17719) +
        (l1 ~/ 5670) * ((43 * l1) ~/ 15238);
    final l2 = l1 -
        ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
        (j ~/ 16) * ((15238 * j) ~/ 43) +
        29;
    final month = (24 * l2) ~/ 709;
    final day = l2 - (709 * month) ~/ 24;
    final year = 30 * n + j - 30;

    return (day: day, month: month, year: year);
  }

  static String format(DateTime date) {
    final h = fromGregorian(date);
    return '${toArabicNumerals(h.day.toString())} ${_hijriMonths[h.month - 1]} ${toArabicNumerals(h.year.toString())}';
  }
}
