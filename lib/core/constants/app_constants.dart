class AppConstants {
  static const String appName = 'داليا للقرآن الكريم و إتجاه القبلة و مواقيت الصلاة';

  // SharedPreferences keys
  static const String keyTheme = 'theme_mode';
  static const String keyFontScale = 'font_scale';
  static const String keyLastReadSurah = 'last_read_surah';
  static const String keyLastReadSurahName = 'last_read_surah_name';
  static const String keyLastReadAyah = 'last_read_ayah';
  static const String keyLastReadPage = 'last_read_page';
  static const String keyLatitude = 'latitude';
  static const String keyLongitude = 'longitude';
  static const String keyCityName = 'city_name';
  static const String keyCalcMethod = 'calc_method';
  static const String keyNotifyFajr = 'notify_fajr';
  static const String keyNotifyDhuhr = 'notify_dhuhr';
  static const String keyNotifyAsr = 'notify_asr';
  static const String keyNotifyMaghrib = 'notify_maghrib';
  static const String keyNotifyIsha = 'notify_isha';

  // Notification channel IDs
  static const String notifChannelId = 'prayer_times';
  static const String notifChannelName = 'أوقات الصلاة';

  // Prayer notification IDs
  static const int notifFajr = 1;
  static const int notifDhuhr = 2;
  static const int notifAsr = 3;
  static const int notifMaghrib = 4;
  static const int notifIsha = 5;
}
