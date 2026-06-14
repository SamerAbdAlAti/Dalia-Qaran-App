const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

String toArabicNumerals(String s) {
  return s.split('').map((c) {
    final d = int.tryParse(c);
    return d != null ? _arabicDigits[d] : c;
  }).join();
}

String formatPrayerTime(DateTime time) {
  final h = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final m = time.minute.toString().padLeft(2, '0');
  final period = time.hour < 12 ? 'ص' : 'م';
  return '${toArabicNumerals(h.toString())}:${toArabicNumerals(m)} $period';
}
