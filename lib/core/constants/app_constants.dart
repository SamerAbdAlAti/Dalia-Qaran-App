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

  // Notification settings
  static const String keyNotifSound = 'notif_sound';
  static const String keyNotifReminderMin = 'notif_reminder_min';
  static const String keyNotifVibrate = 'notif_vibrate';
  static const String keyBatteryOptAsked = 'battery_opt_asked';
  static const String keyCustomSoundUri = 'notif_custom_sound_uri';
  static const String keyBackgroundMode = 'background_mode';

  // Background service notification ID
  static const int notifBackgroundService = 999;

  // Prayer notification IDs (0-4 today, 50-54 tomorrow)
  static const int notifFajr = 0;
  static const int notifDhuhr = 1;
  static const int notifAsr = 2;
  static const int notifMaghrib = 3;
  static const int notifIsha = 4;
  static const int notifFajrReminder = 10;
  static const int notifDhuhrReminder = 11;
  static const int notifAsrReminder = 12;
  static const int notifMaghribReminder = 13;
  static const int notifIshaReminder = 14;

  // Tomorrow's prayer notification IDs (today + 50)
  static const int notifTomorrowOffset = 50;

  // Reminder notification IDs (20+)
  static const int notifAdhkarMorning = 20;
  static const int notifAdhkarEvening = 21;
  static const int notifFajrSunnah = 22;
  static const int notifQiyamLayl = 23;
  static const int notifDuha = 24;
  static const int notifQuranReading = 25;
  static const int notifSalahAnnabi = 26;

  // Dhikr Audio Reminder IDs — legacy single IDs (kept for cancel-on-migrate)
  static const int notifDhikrIstighfar = 30;
  static const int notifDhikrSalawat = 31;
  static const int notifDhikrTasbih = 32;
  static const int notifDhikrPostPrayer = 33;

  // Dhikr interval slot ranges (100 slots each — supports custom intervals down to ~10 min)
  static const int notifDhikrIstighfarBase = 200; // 200-299
  static const int notifDhikrSalawatBase   = 300; // 300-399
  static const int notifDhikrTasbihBase    = 400; // 400-499
  static const int notifDhikrSlotCount     = 100;

  // Reminder SharedPreferences keys
  static const String keyReminderAdhkarMorning = 'reminder_adhkar_morning';
  static const String keyReminderAdhkarMorningTime = 'reminder_adhkar_morning_time';
  static const String keyReminderAdhkarEvening = 'reminder_adhkar_evening';
  static const String keyReminderAdhkarEveningTime = 'reminder_adhkar_evening_time';
  static const String keyReminderFajrSunnah = 'reminder_fajr_sunnah';
  static const String keyReminderFajrSunnahMin = 'reminder_fajr_sunnah_min';
  static const String keyReminderQiyam = 'reminder_qiyam';
  static const String keyReminderDuha = 'reminder_duha';
  static const String keyReminderDuhaTime = 'reminder_duha_time';
  static const String keyReminderQuran = 'reminder_quran';
  static const String keyReminderQuranTime = 'reminder_quran_time';
  static const String keyReminderSalahAnnabi = 'reminder_salah_annabi';
  static const String keyReminderSalahAnnabiTime = 'reminder_salah_annabi_time';

  // Dhikr Audio Reminder keys
  static const String keyDhikrIstighfar         = 'dhikr_istighfar';
  static const String keyDhikrIstighfarInterval  = 'dhikr_istighfar_interval'; // int minutes
  static const String keyDhikrIstighfarSound     = 'dhikr_istighfar_sound';
  static const String keyDhikrSalawat            = 'dhikr_salawat';
  static const String keyDhikrSalawatInterval    = 'dhikr_salawat_interval';
  static const String keyDhikrSalawatSound       = 'dhikr_salawat_sound';
  static const String keyDhikrTasbih             = 'dhikr_tasbih';
  static const String keyDhikrTasbihInterval     = 'dhikr_tasbih_interval';
  static const String keyDhikrTasbihSound        = 'dhikr_tasbih_sound';
  static const String keyDhikrPostPrayer         = 'dhikr_post_prayer';

  // Quran Audio
  static const String keyAudioSelectedReciter = 'quran_audio_selected_reciter';
  static const String keyAudioRecitersCache   = 'quran_audio_reciters_cache';
  static const String keyAudioFullDownload    = 'quran_audio_full_download';
}
