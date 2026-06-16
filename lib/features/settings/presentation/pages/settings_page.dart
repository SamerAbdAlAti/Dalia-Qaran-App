import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/platform_service.dart';
import '../../../../core/services/reminders_service.dart';
import '../../../../core/state/font_scale_cubit.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../home/presentation/cubit/home_cubit.dart';

// ─── Page ───

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _notifyFajr, _notifyDhuhr, _notifyAsr, _notifyMaghrib, _notifyIsha;
  late String _soundId;
  late int _reminderMin;
  late bool _vibrate;
  late bool _backgroundMode;
  bool _hasExactAlarmPermission = false;
  bool _batteryOptIgnored = false;
  bool _pickingCustomSound = false;

  // ─── Reminder state ───
  late bool _tajweedMode;
  late int _quranFontWeight;
  late bool _remAdhkarMorning, _remAdhkarEvening, _remFajrSunnah,
      _remQiyam, _remDuha, _remQuran, _remSalahAnnabi;
  late String _remAdhkarMorningTime, _remAdhkarEveningTime,
      _remDuhaTime, _remQuranTime, _remSalahAnnabiTime;
  late int _remFajrSunnahMin;

  // ─── Dhikr reminder state ───
  late bool _dhikrIstighfar, _dhikrSalawat, _dhikrTasbih, _dhikrPostPrayer;
  late int _dhikrIstighfarInterval, _dhikrSalawatInterval, _dhikrTasbihInterval;
  late String _dhikrIstighfarSound, _dhikrSalawatSound, _dhikrTasbihSound;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _checkPermissions();
  }

  void _loadPrefs() {
    final p = sl<SharedPreferences>();
    setState(() {
      _notifyFajr = p.getBool(AppConstants.keyNotifyFajr) ?? true;
      _notifyDhuhr = p.getBool(AppConstants.keyNotifyDhuhr) ?? true;
      _notifyAsr = p.getBool(AppConstants.keyNotifyAsr) ?? true;
      _notifyMaghrib = p.getBool(AppConstants.keyNotifyMaghrib) ?? true;
      _notifyIsha = p.getBool(AppConstants.keyNotifyIsha) ?? true;
      _soundId = p.getString(AppConstants.keyNotifSound) ?? 'default';
      _reminderMin = p.getInt(AppConstants.keyNotifReminderMin) ?? 0;
      _vibrate = p.getBool(AppConstants.keyNotifVibrate) ?? true;
      _backgroundMode = p.getBool(AppConstants.keyBackgroundMode) ?? false;
      _tajweedMode = p.getBool('mushaf_tajweed_mode') ?? false;
      _quranFontWeight = p.getInt('mushaf_font_weight') ?? 400;

      _remAdhkarMorning = p.getBool(AppConstants.keyReminderAdhkarMorning) ?? false;
      _remAdhkarMorningTime = p.getString(AppConstants.keyReminderAdhkarMorningTime) ?? '06:00';
      _remAdhkarEvening = p.getBool(AppConstants.keyReminderAdhkarEvening) ?? false;
      _remAdhkarEveningTime = p.getString(AppConstants.keyReminderAdhkarEveningTime) ?? '16:00';
      _remFajrSunnah = p.getBool(AppConstants.keyReminderFajrSunnah) ?? false;
      _remFajrSunnahMin = p.getInt(AppConstants.keyReminderFajrSunnahMin) ?? 20;
      _remQiyam = p.getBool(AppConstants.keyReminderQiyam) ?? false;
      _remDuha = p.getBool(AppConstants.keyReminderDuha) ?? false;
      _remDuhaTime = p.getString(AppConstants.keyReminderDuhaTime) ?? '09:00';
      _remQuran = p.getBool(AppConstants.keyReminderQuran) ?? false;
      _remQuranTime = p.getString(AppConstants.keyReminderQuranTime) ?? '20:00';
      _remSalahAnnabi = p.getBool(AppConstants.keyReminderSalahAnnabi) ?? false;
      _remSalahAnnabiTime = p.getString(AppConstants.keyReminderSalahAnnabiTime) ?? '12:00';

      _dhikrIstighfar         = p.getBool(AppConstants.keyDhikrIstighfar) ?? false;
      _dhikrIstighfarInterval = p.getInt(AppConstants.keyDhikrIstighfarInterval) ?? 60;
      _dhikrIstighfarSound    = p.getString(AppConstants.keyDhikrIstighfarSound) ?? 'dhikr_istighfar';
      _dhikrSalawat           = p.getBool(AppConstants.keyDhikrSalawat) ?? false;
      _dhikrSalawatInterval   = p.getInt(AppConstants.keyDhikrSalawatInterval) ?? 60;
      _dhikrSalawatSound      = p.getString(AppConstants.keyDhikrSalawatSound) ?? 'dhikr_salawat';
      _dhikrTasbih            = p.getBool(AppConstants.keyDhikrTasbih) ?? false;
      _dhikrTasbihInterval    = p.getInt(AppConstants.keyDhikrTasbihInterval) ?? 60;
      _dhikrTasbihSound       = p.getString(AppConstants.keyDhikrTasbihSound) ?? 'dhikr_tasbih';
      _dhikrPostPrayer        = p.getBool(AppConstants.keyDhikrPostPrayer) ?? false;
    });
  }

  Future<void> _scheduleReminders() async {
    final p = sl<SharedPreferences>();
    // Grab prayer times from HomeCubit if available
    DateTime? fajr, isha;
    final homeState = context.read<HomeCubit>().state;
    if (homeState is HomeLoaded) {
      fajr = homeState.prayerTimes.fajr;
      isha = homeState.prayerTimes.isha;
    }
    await RemindersService.scheduleAll(
      prefs: {
        AppConstants.keyReminderAdhkarMorning: p.getBool(AppConstants.keyReminderAdhkarMorning) ?? false,
        AppConstants.keyReminderAdhkarMorningTime: p.getString(AppConstants.keyReminderAdhkarMorningTime) ?? '06:00',
        AppConstants.keyReminderAdhkarEvening: p.getBool(AppConstants.keyReminderAdhkarEvening) ?? false,
        AppConstants.keyReminderAdhkarEveningTime: p.getString(AppConstants.keyReminderAdhkarEveningTime) ?? '16:00',
        AppConstants.keyReminderFajrSunnah: p.getBool(AppConstants.keyReminderFajrSunnah) ?? false,
        AppConstants.keyReminderFajrSunnahMin: p.getInt(AppConstants.keyReminderFajrSunnahMin) ?? 20,
        AppConstants.keyReminderQiyam: p.getBool(AppConstants.keyReminderQiyam) ?? false,
        AppConstants.keyReminderDuha: p.getBool(AppConstants.keyReminderDuha) ?? false,
        AppConstants.keyReminderDuhaTime: p.getString(AppConstants.keyReminderDuhaTime) ?? '09:00',
        AppConstants.keyReminderQuran: p.getBool(AppConstants.keyReminderQuran) ?? false,
        AppConstants.keyReminderQuranTime: p.getString(AppConstants.keyReminderQuranTime) ?? '20:00',
        AppConstants.keyReminderSalahAnnabi: p.getBool(AppConstants.keyReminderSalahAnnabi) ?? false,
        AppConstants.keyReminderSalahAnnabiTime: p.getString(AppConstants.keyReminderSalahAnnabiTime) ?? '12:00',
      },
      fajrTime: fajr,
      ishaTime: isha,
    );
  }

  Future<void> _scheduleDhikrReminders() async {
    final p = sl<SharedPreferences>();
    await RemindersService.scheduleDhikrAll(prefs: {
      AppConstants.keyDhikrIstighfar:         p.getBool(AppConstants.keyDhikrIstighfar) ?? false,
      AppConstants.keyDhikrIstighfarInterval: p.getInt(AppConstants.keyDhikrIstighfarInterval) ?? 60,
      AppConstants.keyDhikrIstighfarSound:    p.getString(AppConstants.keyDhikrIstighfarSound) ?? 'dhikr_istighfar',
      AppConstants.keyDhikrSalawat:           p.getBool(AppConstants.keyDhikrSalawat) ?? false,
      AppConstants.keyDhikrSalawatInterval:   p.getInt(AppConstants.keyDhikrSalawatInterval) ?? 60,
      AppConstants.keyDhikrSalawatSound:      p.getString(AppConstants.keyDhikrSalawatSound) ?? 'dhikr_salawat',
      AppConstants.keyDhikrTasbih:            p.getBool(AppConstants.keyDhikrTasbih) ?? false,
      AppConstants.keyDhikrTasbihInterval:    p.getInt(AppConstants.keyDhikrTasbihInterval) ?? 60,
      AppConstants.keyDhikrTasbihSound:       p.getString(AppConstants.keyDhikrTasbihSound) ?? 'dhikr_tasbih',
      AppConstants.keyDhikrPostPrayer:        p.getBool(AppConstants.keyDhikrPostPrayer) ?? false,
    });
  }

  Future<void> _toggleDhikr(String key, bool value) async {
    setState(() {
      switch (key) {
        case AppConstants.keyDhikrIstighfar:  _dhikrIstighfar = value;
        case AppConstants.keyDhikrSalawat:    _dhikrSalawat = value;
        case AppConstants.keyDhikrTasbih:     _dhikrTasbih = value;
        case AppConstants.keyDhikrPostPrayer: _dhikrPostPrayer = value;
      }
    });
    await _savePref(key, value);
    await _scheduleDhikrReminders();
  }

  Future<void> _pickDhikrInterval(String intervalKey, int current) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DhikrIntervalSheet(currentMinutes: current),
    );
    if (picked == null || !mounted) return;
    setState(() {
      switch (intervalKey) {
        case AppConstants.keyDhikrIstighfarInterval: _dhikrIstighfarInterval = picked;
        case AppConstants.keyDhikrSalawatInterval:   _dhikrSalawatInterval = picked;
        case AppConstants.keyDhikrTasbihInterval:    _dhikrTasbihInterval = picked;
      }
    });
    await _savePref(intervalKey, picked);
    await _scheduleDhikrReminders();
  }

  void _pickDhikrSound(String soundKey, String currentId) {
    final title = switch (soundKey) {
      AppConstants.keyDhikrIstighfarSound => 'صوت الاستغفار',
      AppConstants.keyDhikrSalawatSound   => 'صوت الصلاة على النبي ﷺ',
      AppConstants.keyDhikrTasbihSound    => 'صوت التسبيح',
      _                                   => 'صوت تذكير الذكر',
    };
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DhikrSoundSheet(
        currentId: currentId,
        title: title,
        onPick: (id) async {
          setState(() {
            switch (soundKey) {
              case AppConstants.keyDhikrIstighfarSound: _dhikrIstighfarSound = id;
              case AppConstants.keyDhikrSalawatSound:   _dhikrSalawatSound = id;
              case AppConstants.keyDhikrTasbihSound:    _dhikrTasbihSound = id;
            }
          });
          await _savePref(soundKey, id);
          await _scheduleDhikrReminders();
        },
      ),
    );
  }

  static String dhikrIntervalLabel(int minutes) => switch (minutes) {
    30   => 'كل ٣٠ دقيقة',
    60   => 'كل ساعة',
    120  => 'كل ساعتين',
    180  => 'كل ٣ ساعات',
    360  => 'كل ٦ ساعات',
    1440 => 'مرة يومياً',
    _    => 'كل ساعة',
  };

  Future<void> _toggleReminder(String key, bool value, {String? stateField}) async {
    setState(() {
      switch (key) {
        case AppConstants.keyReminderAdhkarMorning: _remAdhkarMorning = value;
        case AppConstants.keyReminderAdhkarEvening: _remAdhkarEvening = value;
        case AppConstants.keyReminderFajrSunnah:    _remFajrSunnah = value;
        case AppConstants.keyReminderQiyam:          _remQiyam = value;
        case AppConstants.keyReminderDuha:           _remDuha = value;
        case AppConstants.keyReminderQuran:          _remQuran = value;
        case AppConstants.keyReminderSalahAnnabi:   _remSalahAnnabi = value;
      }
    });
    await _savePref(key, value);
    await _scheduleReminders();
  }

  Future<void> _pickReminderTime(String timeKey, String currentTime) async {
    final parts = currentTime.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 6,
      minute: int.tryParse(parts[1]) ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      switch (timeKey) {
        case AppConstants.keyReminderAdhkarMorningTime:  _remAdhkarMorningTime = formatted;
        case AppConstants.keyReminderAdhkarEveningTime:  _remAdhkarEveningTime = formatted;
        case AppConstants.keyReminderDuhaTime:            _remDuhaTime = formatted;
        case AppConstants.keyReminderQuranTime:           _remQuranTime = formatted;
        case AppConstants.keyReminderSalahAnnabiTime:    _remSalahAnnabiTime = formatted;
      }
    });
    await _savePref(timeKey, formatted);
    await _scheduleReminders();
  }

  Future<void> _checkPermissions() async {
    final has = await NotificationService.checkExactAlarmPermission();
    final battOpt = await PlatformService.isBatteryOptimizationIgnored();
    if (mounted) {
      setState(() {
        _hasExactAlarmPermission = has;
        _batteryOptIgnored = battOpt;
      });
    }
  }

  Future<void> _savePref(String key, dynamic value) async {
    final p = sl<SharedPreferences>();
    if (value is bool) await p.setBool(key, value);
    if (value is String) await p.setString(key, value);
    if (value is int) await p.setInt(key, value);
  }

  Future<void> _requestExactAlarm() async {
    final plugin = FlutterLocalNotificationsPlugin();
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestExactAlarmsPermission();
    await _checkPermissions();
  }

  Future<void> _requestBatteryOpt() async {
    await PlatformService.requestBatteryOptimizationExemption();
    await Future.delayed(const Duration(seconds: 1));
    await _checkPermissions();
  }

  Future<void> _toggleBackgroundMode(bool value) async {
    setState(() => _backgroundMode = value);
    await _savePref(AppConstants.keyBackgroundMode, value);
    if (value) {
      await NotificationService.showBackgroundServiceNotification();
    } else {
      await NotificationService.cancelBackgroundServiceNotification();
    }
  }

  Future<void> _pickCustomSound() async {
    setState(() => _pickingCustomSound = true);
    try {
      final uri = await NotificationService.pickAndSaveCustomSound();
      if (uri != null && mounted) {
        await _savePref(AppConstants.keyCustomSoundUri, uri);
        await _savePref(AppConstants.keyNotifSound, 'custom');
        setState(() => _soundId = 'custom');
      }
    } finally {
      if (mounted) setState(() => _pickingCustomSound = false);
    }
  }

  void _pickSound() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SoundPickerSheet(
        currentId: _soundId,
        isPickingCustom: _pickingCustomSound,
        onPick: (id) async {
          if (id == 'custom') {
            // sheet already popped itself before calling onPick
            await _pickCustomSound();
          } else {
            setState(() => _soundId = id);
            await _savePref(AppConstants.keyNotifSound, id);
          }
        },
      ),
    );
  }

  void _pickReminder() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReminderPickerSheet(
        currentMin: _reminderMin,
        onPick: (min) async {
          setState(() => _reminderMin = min);
          await _savePref(AppConstants.keyNotifReminderMin, min);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _SettingsHeader(colors: colors),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                children: [
                  // ─── المظهر ───
                  _SectionTitle(title: 'المظهر', colors: colors),
                  _ThemeCard(colors: colors, isDark: isDark),
                  SizedBox(height: 12.h),

                  // ─── حجم الخط ───
                  _SectionTitle(title: 'حجم الخط', colors: colors),
                  _FontScaleCard(colors: colors),
                  SizedBox(height: 12.h),

                  // ─── تنبيهات الصلاة ───
                  _SectionTitle(title: 'تنبيهات الصلاة', colors: colors),

                  // Permission banner
                  if (!_hasExactAlarmPermission) ...[
                    _PermissionBanner(
                      colors: colors,
                      onRequest: _requestExactAlarm,
                    ),
                    SizedBox(height: 8.h),
                  ],

                  // Sound + Reminder + Vibration card
                  _NotifSettingsCard(
                    colors: colors,
                    soundId: _soundId,
                    reminderMin: _reminderMin,
                    vibrate: _vibrate,
                    onSoundTap: _pickSound,
                    onReminderTap: _pickReminder,
                    onVibrateTap: (v) async {
                      setState(() => _vibrate = v);
                      await _savePref(AppConstants.keyNotifVibrate, v);
                    },
                  ),
                  SizedBox(height: 8.h),

                  // Per-prayer toggles
                  _PrayerToggleCard(
                    colors: colors,
                    notifyFajr: _notifyFajr,
                    notifyDhuhr: _notifyDhuhr,
                    notifyAsr: _notifyAsr,
                    notifyMaghrib: _notifyMaghrib,
                    notifyIsha: _notifyIsha,
                    onToggle: (key, value) async {
                      setState(() {
                        switch (key) {
                          case AppConstants.keyNotifyFajr:
                            _notifyFajr = value;
                          case AppConstants.keyNotifyDhuhr:
                            _notifyDhuhr = value;
                          case AppConstants.keyNotifyAsr:
                            _notifyAsr = value;
                          case AppConstants.keyNotifyMaghrib:
                            _notifyMaghrib = value;
                          case AppConstants.keyNotifyIsha:
                            _notifyIsha = value;
                        }
                      });
                      await _savePref(key, value);
                    },
                  ),
                  SizedBox(height: 8.h),

                  // ─── الخدمة في الخلفية ───
                  _SectionTitle(title: 'الخدمة في الخلفية', colors: colors),
                  _BackgroundModeCard(
                    colors: colors,
                    backgroundMode: _backgroundMode,
                    batteryOptIgnored: _batteryOptIgnored,
                    onToggle: _toggleBackgroundMode,
                    onRequestBatteryOpt: _requestBatteryOpt,
                  ),
                  SizedBox(height: 12.h),

                  // ─── التذكيرات اليومية ───
                  _SectionTitle(title: 'التذكيرات اليومية', colors: colors),
                  _RemindersCard(
                    colors: colors,
                    remAdhkarMorning: _remAdhkarMorning,
                    remAdhkarMorningTime: _remAdhkarMorningTime,
                    remAdhkarEvening: _remAdhkarEvening,
                    remAdhkarEveningTime: _remAdhkarEveningTime,
                    remFajrSunnah: _remFajrSunnah,
                    remFajrSunnahMin: _remFajrSunnahMin,
                    remQiyam: _remQiyam,
                    remDuha: _remDuha,
                    remDuhaTime: _remDuhaTime,
                    remQuran: _remQuran,
                    remQuranTime: _remQuranTime,
                    remSalahAnnabi: _remSalahAnnabi,
                    remSalahAnnabiTime: _remSalahAnnabiTime,
                    onToggle: _toggleReminder,
                    onPickTime: _pickReminderTime,
                    onPickFajrSunnahMin: (min) async {
                      setState(() => _remFajrSunnahMin = min);
                      await _savePref(AppConstants.keyReminderFajrSunnahMin, min);
                      await _scheduleReminders();
                    },
                  ),
                  SizedBox(height: 12.h),

                  // ─── تذكيرات الذكر الصوتية ───
                  _SectionTitle(title: 'تذكيرات الذكر الصوتية', colors: colors),
                  _DhikrRemindersCard(
                    colors: colors,
                    dhikrIstighfar: _dhikrIstighfar,
                    dhikrIstighfarInterval: _dhikrIstighfarInterval,
                    dhikrIstighfarSound: _dhikrIstighfarSound,
                    dhikrSalawat: _dhikrSalawat,
                    dhikrSalawatInterval: _dhikrSalawatInterval,
                    dhikrSalawatSound: _dhikrSalawatSound,
                    dhikrTasbih: _dhikrTasbih,
                    dhikrTasbihInterval: _dhikrTasbihInterval,
                    dhikrTasbihSound: _dhikrTasbihSound,
                    dhikrPostPrayer: _dhikrPostPrayer,
                    onToggle: _toggleDhikr,
                    onPickInterval: _pickDhikrInterval,
                    onPickSound: _pickDhikrSound,
                  ),
                  SizedBox(height: 12.h),

                  // ─── القرآن الكريم ───
                  _SectionTitle(title: 'القرآن الكريم', colors: colors),
                  _QuranSettingsCard(
                    colors: colors,
                    tajweedMode: _tajweedMode,
                    fontWeight: _quranFontWeight,
                    onTajweedToggle: (v) async {
                      setState(() => _tajweedMode = v);
                      await sl<SharedPreferences>().setBool('mushaf_tajweed_mode', v);
                    },
                    onFontWeightChanged: (w) async {
                      setState(() => _quranFontWeight = w);
                      await sl<SharedPreferences>().setInt('mushaf_font_weight', w);
                    },
                  ),
                  SizedBox(height: 12.h),

                  // ─── عن التطبيق ───
                  _SectionTitle(title: 'عن التطبيق', colors: colors),
                  _AboutCard(colors: colors),
                  SizedBox(height: 12.h),

                  // ─── Debug (debug builds only) ───
                  if (kDebugMode) ...[
                    _SectionTitle(title: '🛠 اختبار (Debug)', colors: colors),
                    _DebugCard(
                      colors: colors,
                      soundId: _soundId,
                      customSoundUri: sl<SharedPreferences>().getString(AppConstants.keyCustomSoundUri),
                      hasExactAlarm: _hasExactAlarmPermission,
                      batteryOptIgnored: _batteryOptIgnored,
                      onRequestExactAlarm: _requestExactAlarm,
                      onRequestBatteryOpt: _requestBatteryOpt,
                    ),
                  ],
                  SizedBox(height: 24.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ───

class _SettingsHeader extends StatelessWidget {
  final AppColorScheme colors;
  const _SettingsHeader({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
      ),
      child: Text(
        'الإعدادات',
        style: TextStyle(
          color: Colors.white,
          fontSize: 22.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Section title ───

class _SectionTitle extends StatelessWidget {
  final String title;
  final AppColorScheme colors;
  const _SectionTitle({required this.title, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h, top: 4.h, right: 4.w),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 13.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration(AppColorScheme colors) => BoxDecoration(
      color: colors.card,
      borderRadius: BorderRadius.circular(14.r),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(10),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );

// ─── Theme card ───

class _ThemeCard extends StatelessWidget {
  final AppColorScheme colors;
  final bool isDark;
  const _ThemeCard({required this.colors, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(colors),
      child: Column(
        children: [
          _ThemeTile(
            label: 'وضع النهار',
            icon: Icons.light_mode_outlined,
            selected: !isDark,
            onTap: () => context.read<ThemeCubit>().setMode(ThemeMode.light),
            colors: colors,
          ),
          Divider(height: 0.5, color: colors.divider, indent: 56.w),
          _ThemeTile(
            label: 'وضع الليل',
            icon: Icons.dark_mode_outlined,
            selected: isDark,
            onTap: () => context.read<ThemeCubit>().setMode(ThemeMode.dark),
            colors: colors,
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final AppColorScheme colors;

  const _ThemeTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? AppColors.primary : colors.textSecondary,
                size: 22.r),
            SizedBox(width: 14.w),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 15.sp,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: AppColors.primary, size: 20.r),
          ],
        ),
      ),
    );
  }
}

// ─── Font Scale card ───

class _FontScaleCard extends StatelessWidget {
  final AppColorScheme colors;
  const _FontScaleCard({required this.colors});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FontScaleCubit, FontScaleState>(
      builder: (context, state) {
        return Container(
          decoration: _cardDecoration(colors),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.text_fields, color: AppColors.primary, size: 22.r),
                  SizedBox(width: 14.w),
                  Text('حجم النص',
                      style: TextStyle(
                          color: colors.textPrimary, fontSize: 15.sp)),
                  const Spacer(),
                  Text(
                    '${(state.scale * 100).round()}٪',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.read<FontScaleCubit>().decrease(),
                    icon: Icon(Icons.remove_circle_outline,
                        color: AppColors.primary, size: 24.r),
                    padding: EdgeInsets.zero,
                    constraints:
                        BoxConstraints(minWidth: 36.r, minHeight: 36.r),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: AppColors.primary.withAlpha(40),
                        thumbColor: AppColors.primary,
                        overlayColor: AppColors.primary.withAlpha(30),
                        trackHeight: 3,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 8),
                      ),
                      child: Slider(
                        value: state.scale,
                        min: FontScaleCubit.min,
                        max: FontScaleCubit.max,
                        onChanged: (v) =>
                            context.read<FontScaleCubit>().setScale(v),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.read<FontScaleCubit>().increase(),
                    icon: Icon(Icons.add_circle_outline,
                        color: AppColors.primary, size: 24.r),
                    padding: EdgeInsets.zero,
                    constraints:
                        BoxConstraints(minWidth: 36.r, minHeight: 36.r),
                  ),
                ],
              ),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'ScheherazadeNew',
                    fontSize: 18.sp * state.scale,
                    color: colors.textPrimary,
                    height: 1.8,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Permission Banner ───

class _PermissionBanner extends StatelessWidget {
  final AppColorScheme colors;
  final VoidCallback onRequest;
  const _PermissionBanner({required this.colors, required this.onRequest});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE67E22).withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: const Color(0xFFE67E22), size: 20.r),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'لضمان وصول التنبيهات حتى مع إغلاق التطبيق، يرجى منح إذن التنبيهات الدقيقة',
              style: TextStyle(
                  color: const Color(0xFFE67E22),
                  fontSize: 11.sp,
                  height: 1.5),
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: onRequest,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: const Color(0xFFE67E22),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                'منح',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Notification Settings Card (sound + reminder + vibration) ───

class _NotifSettingsCard extends StatelessWidget {
  final AppColorScheme colors;
  final String soundId;
  final int reminderMin;
  final bool vibrate;
  final VoidCallback onSoundTap;
  final VoidCallback onReminderTap;
  final ValueChanged<bool> onVibrateTap;

  const _NotifSettingsCard({
    required this.colors,
    required this.soundId,
    required this.reminderMin,
    required this.vibrate,
    required this.onSoundTap,
    required this.onReminderTap,
    required this.onVibrateTap,
  });

  String get _soundLabel {
    final s = kPrayerSounds.where((s) => s.id == soundId).firstOrNull;
    return s?.nameAr ?? 'نغمة النظام';
  }

  String get _reminderLabel {
    final offset = ReminderOffset.values
        .where((r) => r.minutes == reminderMin)
        .firstOrNull;
    return offset?.label ?? 'لا تذكير';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(colors),
      child: Column(
        children: [
          // Sound
          _SettingRow(
            colors: colors,
            icon: Icons.music_note_outlined,
            label: 'صوت الأذان',
            value: _soundLabel,
            onTap: onSoundTap,
          ),
          Divider(height: 0.5, color: colors.divider, indent: 52.w),

          // Reminder
          _SettingRow(
            colors: colors,
            icon: Icons.timer_outlined,
            label: 'تذكير مسبق',
            value: _reminderLabel,
            onTap: onReminderTap,
          ),
          Divider(height: 0.5, color: colors.divider, indent: 52.w),

          // Vibration
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
            child: Row(
              children: [
                Icon(Icons.vibration,
                    color: vibrate ? AppColors.primary : colors.textSecondary,
                    size: 22.r),
                SizedBox(width: 14.w),
                Expanded(
                  child: Text('اهتزاز',
                      style: TextStyle(
                          color: colors.textPrimary, fontSize: 15.sp)),
                ),
                Switch(
                  value: vibrate,
                  onChanged: onVibrateTap,
                  activeThumbColor: AppColors.primary,
                  activeTrackColor: AppColors.primary.withAlpha(180),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final AppColorScheme colors;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _SettingRow({
    required this.colors,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22.r),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: colors.textPrimary, fontSize: 15.sp)),
                  Text(value,
                      style: TextStyle(
                          color: colors.textSecondary, fontSize: 12.sp)),
                ],
              ),
            ),
            Icon(Icons.chevron_left,
                color: colors.textSecondary, size: 20.r),
          ],
        ),
      ),
    );
  }
}

// ─── Prayer Toggle Card ───

class _PrayerToggleCard extends StatelessWidget {
  final AppColorScheme colors;
  final bool notifyFajr, notifyDhuhr, notifyAsr, notifyMaghrib, notifyIsha;
  final void Function(String key, bool value) onToggle;

  const _PrayerToggleCard({
    required this.colors,
    required this.notifyFajr,
    required this.notifyDhuhr,
    required this.notifyAsr,
    required this.notifyMaghrib,
    required this.notifyIsha,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final prayers = [
      ('الفجر', Icons.wb_twilight_outlined, AppConstants.keyNotifyFajr,
          notifyFajr),
      ('الظهر', Icons.wb_sunny_outlined, AppConstants.keyNotifyDhuhr,
          notifyDhuhr),
      ('العصر', Icons.wb_sunny_outlined, AppConstants.keyNotifyAsr, notifyAsr),
      ('المغرب', Icons.wb_twighlight, AppConstants.keyNotifyMaghrib,
          notifyMaghrib),
      ('العشاء', Icons.nights_stay_outlined, AppConstants.keyNotifyIsha,
          notifyIsha),
    ];

    return Container(
      decoration: _cardDecoration(colors),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            child: Row(
              children: [
                Icon(Icons.notifications_outlined,
                    color: colors.textSecondary, size: 16.r),
                SizedBox(width: 8.w),
                Text(
                  'تفعيل التنبيه لكل صلاة',
                  style: TextStyle(
                      color: colors.textSecondary, fontSize: 12.sp),
                ),
              ],
            ),
          ),
          Divider(height: 0.5, color: colors.divider),
          ...prayers.asMap().entries.map((entry) {
            final i = entry.key;
            final (name, icon, key, value) = entry.value;
            return Column(
              children: [
                _PrayerToggleTile(
                  name: name,
                  icon: icon,
                  prefKey: key,
                  value: value,
                  colors: colors,
                  onToggle: onToggle,
                  key: ValueKey(key),
                ),
                if (i < prayers.length - 1)
                  Divider(height: 0.5, color: colors.divider, indent: 56.w),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _PrayerToggleTile extends StatelessWidget {
  final String name;
  final IconData icon;
  final String prefKey;
  final bool value;
  final AppColorScheme colors;
  final void Function(String, bool) onToggle;

  const _PrayerToggleTile({
    super.key,
    required this.name,
    required this.icon,
    required this.prefKey,
    required this.value,
    required this.colors,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: Row(
        children: [
          Icon(icon,
              color: value ? AppColors.primary : colors.textSecondary,
              size: 22.r),
          SizedBox(width: 14.w),
          Expanded(
            child: Text(name,
                style:
                    TextStyle(color: colors.textPrimary, fontSize: 15.sp)),
          ),
          Switch(
            value: value,
            onChanged: (v) => onToggle(prefKey, v),
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withAlpha(180),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

// ─── Background Mode Card ───

class _BackgroundModeCard extends StatelessWidget {
  final AppColorScheme colors;
  final bool backgroundMode;
  final bool batteryOptIgnored;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRequestBatteryOpt;

  const _BackgroundModeCard({
    required this.colors,
    required this.backgroundMode,
    required this.batteryOptIgnored,
    required this.onToggle,
    required this.onRequestBatteryOpt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
            child: Row(
              children: [
                Container(
                  width: 36.r,
                  height: 36.r,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.notifications_active_outlined,
                      color: AppColors.primary, size: 20.r),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إبقاء التنبيهات نشطة',
                          style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600)),
                      Text('إشعار دائم يضمن وصول الأذان حتى مع إغلاق التطبيق',
                          style: TextStyle(
                              color: colors.textSecondary, fontSize: 11.sp)),
                    ],
                  ),
                ),
                Switch(
                  value: backgroundMode,
                  onChanged: onToggle,
                  activeThumbColor: AppColors.primary,
                  activeTrackColor: AppColors.primary.withAlpha(180),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
          if (!batteryOptIgnored) ...[
            Divider(height: 0.5, color: colors.divider),
            InkWell(
              onTap: onRequestBatteryOpt,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(16.r)),
              child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Row(
                  children: [
                    Icon(Icons.battery_saver_outlined,
                        color: AppColors.gold, size: 18.r),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        'السماح بالعمل في الخلفية (موفر البطارية)',
                        style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded,
                        color: AppColors.gold, size: 14.r),
                  ],
                ),
              ),
            ),
          ] else ...[
            Divider(height: 0.5, color: colors.divider),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: AppColors.primary, size: 18.r),
                  SizedBox(width: 10.w),
                  Text('مُعفى من موفر البطارية',
                      style: TextStyle(
                          color: AppColors.primary, fontSize: 13.sp)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Sound Picker Bottom Sheet ───

class _SoundPickerSheet extends StatefulWidget {
  final String currentId;
  final ValueChanged<String> onPick;
  final bool isPickingCustom;

  const _SoundPickerSheet({
    required this.currentId,
    required this.onPick,
    this.isPickingCustom = false,
  });

  @override
  State<_SoundPickerSheet> createState() => _SoundPickerSheetState();
}

class _SoundPickerSheetState extends State<_SoundPickerSheet> {
  late String _selected;
  String? _playing;
  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _selected = widget.currentId;
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = null);
    });
  }

  @override
  void dispose() {
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  Future<void> _preview(PrayerSound sound) async {
    if (sound.assetPath.isEmpty) return;
    if (_playing == sound.id) {
      await _player.stop();
      setState(() => _playing = null);
      return;
    }
    await _player.stop();
    setState(() => _playing = sound.id);
    await _player.play(AssetSource(sound.assetPath.replaceFirst('assets/', '')));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        border: Border(top: BorderSide(color: AppColors.gold, width: 1.5)),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(80),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'اختر صوت الأذان',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'اضغط ▶ للمعاينة قبل الاختيار',
            style:
                TextStyle(color: colors.textSecondary, fontSize: 11.sp),
          ),
          SizedBox(height: 16.h),
          ...kPrayerSounds.map((sound) {
            final isSelected = _selected == sound.id;
            final isPlaying = _playing == sound.id;
            if (sound.isCustom) {
              return _SoundTile(
                sound: sound,
                isSelected: isSelected,
                isPlaying: false,
                isLoading: widget.isPickingCustom,
                colors: colors,
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onPick('custom');
                },
                onPreview: null,
              );
            }
            return _SoundTile(
              sound: sound,
              isSelected: isSelected,
              isPlaying: isPlaying,
              colors: colors,
              onTap: () => setState(() => _selected = sound.id),
              onPreview: sound.assetPath.isNotEmpty
                  ? () => _preview(sound)
                  : null,
            );
          }),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onPick(_selected);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r)),
              ),
              child: Text('حفظ الاختيار',
                  style: TextStyle(
                      fontSize: 15.sp, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoundTile extends StatelessWidget {
  final PrayerSound sound;
  final bool isSelected;
  final bool isPlaying;
  final bool isLoading;
  final AppColorScheme colors;
  final VoidCallback onTap;
  final VoidCallback? onPreview;

  const _SoundTile({
    required this.sound,
    required this.isSelected,
    required this.isPlaying,
    required this.colors,
    required this.onTap,
    required this.onPreview,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22.r,
              height: 22.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : colors.textSecondary.withAlpha(80),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check, color: Colors.white, size: 14.r)
                  : null,
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Text(
                sound.nameAr,
                style: TextStyle(
                  color:
                      isSelected ? AppColors.primary : colors.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (isLoading)
              SizedBox(
                width: 22.r,
                height: 22.r,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            else if (onPreview != null)
              GestureDetector(
                onTap: onPreview,
                child: Container(
                  width: 36.r,
                  height: 36.r,
                  decoration: BoxDecoration(
                    color: isPlaying
                        ? AppColors.primary.withAlpha(20)
                        : colors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isPlaying
                          ? AppColors.primary
                          : colors.divider,
                    ),
                  ),
                  child: Icon(
                    isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    color:
                        isPlaying ? AppColors.primary : colors.textSecondary,
                    size: 18.r,
                  ),
                ),
              )
            else
              SizedBox(width: 36.r),
          ],
        ),
      ),
    );
  }
}

// ─── Reminder Picker Bottom Sheet ───

class _ReminderPickerSheet extends StatelessWidget {
  final int currentMin;
  final ValueChanged<int> onPick;

  const _ReminderPickerSheet(
      {required this.currentMin, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        border: Border(top: BorderSide(color: AppColors.gold, width: 1.5)),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(80),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'التذكير قبل الصلاة',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 16.h),
          ...ReminderOffset.values.map((offset) {
            final isSelected = offset.minutes == currentMin;
            return InkWell(
              onTap: () {
                onPick(offset.minutes);
                Navigator.of(context).pop();
              },
              borderRadius: BorderRadius.circular(10.r),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 4.w, vertical: 12.h),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: isSelected
                          ? AppColors.primary
                          : colors.textSecondary,
                      size: 22.r,
                    ),
                    SizedBox(width: 14.w),
                    Text(
                      offset.label,
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : colors.textPrimary,
                        fontSize: 15.sp,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Reminders Card ───

class _RemindersCard extends StatelessWidget {
  final AppColorScheme colors;
  final bool remAdhkarMorning, remAdhkarEvening, remFajrSunnah,
      remQiyam, remDuha, remQuran, remSalahAnnabi;
  final String remAdhkarMorningTime, remAdhkarEveningTime,
      remDuhaTime, remQuranTime, remSalahAnnabiTime;
  final int remFajrSunnahMin;
  final void Function(String key, bool value) onToggle;
  final void Function(String timeKey, String current) onPickTime;
  final void Function(int min) onPickFajrSunnahMin;

  const _RemindersCard({
    required this.colors,
    required this.remAdhkarMorning,
    required this.remAdhkarMorningTime,
    required this.remAdhkarEvening,
    required this.remAdhkarEveningTime,
    required this.remFajrSunnah,
    required this.remFajrSunnahMin,
    required this.remQiyam,
    required this.remDuha,
    required this.remDuhaTime,
    required this.remQuran,
    required this.remQuranTime,
    required this.remSalahAnnabi,
    required this.remSalahAnnabiTime,
    required this.onToggle,
    required this.onPickTime,
    required this.onPickFajrSunnahMin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        children: [
          _ReminderTile(
            colors: colors,
            emoji: '🌅',
            title: 'أذكار الصباح',
            subtitle: 'تذكير يومي بأذكار الصباح',
            enabled: remAdhkarMorning,
            timeValue: remAdhkarMorningTime,
            onToggle: (v) => onToggle(AppConstants.keyReminderAdhkarMorning, v),
            onTimeTap: () => onPickTime(AppConstants.keyReminderAdhkarMorningTime, remAdhkarMorningTime),
          ),
          _divider(colors),
          _ReminderTile(
            colors: colors,
            emoji: '🌆',
            title: 'أذكار المساء',
            subtitle: 'تذكير يومي بأذكار المساء',
            enabled: remAdhkarEvening,
            timeValue: remAdhkarEveningTime,
            onToggle: (v) => onToggle(AppConstants.keyReminderAdhkarEvening, v),
            onTimeTap: () => onPickTime(AppConstants.keyReminderAdhkarEveningTime, remAdhkarEveningTime),
          ),
          _divider(colors),
          _ReminderTile(
            colors: colors,
            emoji: '🕌',
            title: 'سنة الفجر القبلية',
            subtitle: 'قبل أذان الفجر بـ ${_minLabel(remFajrSunnahMin)}',
            enabled: remFajrSunnah,
            onToggle: (v) => onToggle(AppConstants.keyReminderFajrSunnah, v),
            onTimeTap: remFajrSunnah
                ? () => _pickFajrMin(context, remFajrSunnahMin, onPickFajrSunnahMin)
                : null,
            timeLabel: _minLabel(remFajrSunnahMin),
          ),
          _divider(colors),
          _ReminderTile(
            colors: colors,
            emoji: '🌙',
            title: 'قيام الليل',
            subtitle: 'الثلث الأخير من الليل — يُحسب تلقائياً',
            enabled: remQiyam,
            onToggle: (v) => onToggle(AppConstants.keyReminderQiyam, v),
          ),
          _divider(colors),
          _ReminderTile(
            colors: colors,
            emoji: '☀️',
            title: 'صلاة الضحى',
            subtitle: 'تذكير يومي بصلاة الضحى',
            enabled: remDuha,
            timeValue: remDuhaTime,
            onToggle: (v) => onToggle(AppConstants.keyReminderDuha, v),
            onTimeTap: () => onPickTime(AppConstants.keyReminderDuhaTime, remDuhaTime),
          ),
          _divider(colors),
          _ReminderTile(
            colors: colors,
            emoji: '📖',
            title: 'تلاوة القرآن',
            subtitle: 'تذكير يومي بقراءة القرآن الكريم',
            enabled: remQuran,
            timeValue: remQuranTime,
            onToggle: (v) => onToggle(AppConstants.keyReminderQuran, v),
            onTimeTap: () => onPickTime(AppConstants.keyReminderQuranTime, remQuranTime),
          ),
          _divider(colors),
          _ReminderTile(
            colors: colors,
            emoji: '🤲',
            title: 'الصلاة على النبي ﷺ',
            subtitle: 'تذكير يومي بالصلاة على رسول الله',
            enabled: remSalahAnnabi,
            timeValue: remSalahAnnabiTime,
            onToggle: (v) => onToggle(AppConstants.keyReminderSalahAnnabi, v),
            onTimeTap: () => onPickTime(AppConstants.keyReminderSalahAnnabiTime, remSalahAnnabiTime),
          ),
        ],
      ),
    );
  }

  static Widget _divider(AppColorScheme colors) =>
      Divider(height: 0.5, color: colors.divider, indent: 16.w, endIndent: 16.w);

  static String _minLabel(int min) {
    switch (min) {
      case 10: return '١٠ دقائق';
      case 15: return '١٥ دقيقة';
      case 20: return '٢٠ دقيقة';
      case 30: return '٣٠ دقيقة';
      default: return '$min دقيقة';
    }
  }

  static void _pickFajrMin(BuildContext ctx, int current, void Function(int) onPick) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final colors = ctx.colors;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36.w, height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(80),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text('وقت سنة الفجر قبل الأذان',
                  style: TextStyle(color: colors.textPrimary, fontSize: 15.sp, fontWeight: FontWeight.w700)),
              SizedBox(height: 12.h),
              for (final min in [10, 15, 20, 30])
                InkWell(
                  onTap: () { onPick(min); Navigator.pop(ctx); },
                  borderRadius: BorderRadius.circular(10.r),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 12.h),
                    child: Row(
                      children: [
                        Icon(
                          current == min ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: current == min ? AppColors.primary : colors.textSecondary,
                          size: 20.r,
                        ),
                        SizedBox(width: 12.w),
                        Text(_minLabel(min),
                            style: TextStyle(
                              color: current == min ? AppColors.primary : colors.textPrimary,
                              fontSize: 14.sp,
                              fontWeight: current == min ? FontWeight.w600 : FontWeight.w400,
                            )),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final AppColorScheme colors;
  final String emoji;
  final String title;
  final String subtitle;
  final bool enabled;
  final String? timeValue;
  final String? timeLabel;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onTimeTap;

  const _ReminderTile({
    required this.colors,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onToggle,
    this.timeValue,
    this.timeLabel,
    this.onTimeTap,
  });

  @override
  Widget build(BuildContext context) {
    final showTime = (timeValue != null || timeLabel != null) && enabled && onTimeTap != null;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
      child: Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: 22.sp)),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    )),
                Text(subtitle,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11.sp,
                    )),
              ],
            ),
          ),
          if (showTime)
            GestureDetector(
              onTap: onTimeTap,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                margin: EdgeInsets.only(left: 6.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: AppColors.primary.withAlpha(60)),
                ),
                child: Text(
                  timeLabel ?? _formatTime(timeValue!),
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Switch(
            value: enabled,
            onChanged: onToggle,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withAlpha(180),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  static String _formatTime(String hhmm) {
    final p = hhmm.split(':');
    final h = int.tryParse(p[0]) ?? 0;
    final m = int.tryParse(p[1]) ?? 0;
    final period = h < 12 ? 'ص' : 'م';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayH:${m.toString().padLeft(2, '0')} $period';
  }
}

// ─── Quran settings card ───

class _QuranSettingsCard extends StatelessWidget {
  final AppColorScheme colors;
  final bool tajweedMode;
  final int fontWeight;
  final ValueChanged<bool> onTajweedToggle;
  final ValueChanged<int> onFontWeightChanged;

  const _QuranSettingsCard({
    required this.colors,
    required this.tajweedMode,
    required this.fontWeight,
    required this.onTajweedToggle,
    required this.onFontWeightChanged,
  });

  static const _weights = [
    (label: 'خفيف', value: 300),
    (label: 'عادي', value: 400),
    (label: 'سميك', value: 700),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(12.r),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
            title: Text(
              'ألوان التجويد',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            subtitle: Text(
              'تلوين أحكام التجويد في المصحف',
              style: TextStyle(fontSize: 12.sp, color: colors.textSecondary),
            ),
            value: tajweedMode,
            onChanged: onTajweedToggle,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
          ),
          Divider(height: 1, color: colors.surface),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'سُمك خط القرآن',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'اختر وزن الخط في المصحف',
                        style: TextStyle(fontSize: 12.sp, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Row(
                  children: _weights.map((w) {
                    final selected = fontWeight == w.value;
                    return Padding(
                      padding: EdgeInsets.only(right: 6.w),
                      child: GestureDetector(
                        onTap: () => onFontWeightChanged(w.value),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primary : colors.surface,
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                              color: selected ? AppColors.primary : colors.textSecondary.withAlpha(80),
                            ),
                          ),
                          child: Text(
                            w.label,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                              color: selected ? Colors.white : colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── About card ───

class _AboutCard extends StatelessWidget {
  final AppColorScheme colors;
  const _AboutCard({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(colors),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      child: Column(
        children: [
          // App icon + name
          Container(
            width: 56.r,
            height: 56.r,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(Icons.menu_book_rounded, color: Colors.white, size: 28.r),
          ),
          SizedBox(height: 10.h),
          Text(
            'داليا',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'القرآن الكريم • أوقات الصلاة • اتجاه القبلة',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
          ),
          SizedBox(height: 4.h),
          Text(
            'الإصدار 1.0.0',
            style: TextStyle(color: colors.textSecondary, fontSize: 11.sp),
          ),

          SizedBox(height: 20.h),
          Divider(color: colors.divider),
          SizedBox(height: 16.h),

          // Dedication
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(
                  '🕊',
                  style: TextStyle(fontSize: 22.sp),
                ),
                SizedBox(height: 8.h),
                Text(
                  'صدقةٌ جاريةٌ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.goldLight,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'عن أرواح شهدائنا الأحبّاء',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12.sp,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 10.h),
                _MartyrRow(name: 'الشهيدة داليا عبد العاطي عبد العاطي', colors: colors),
                SizedBox(height: 4.h),
                _MartyrRow(name: 'الشهيد محمد عطا الفرام', colors: colors),
                SizedBox(height: 4.h),
                _MartyrRow(name: 'الشهيد ماهر محمد الفرام', colors: colors),
                SizedBox(height: 8.h),
                Text(
                  'رحمهم الله وأسكنهم فسيح جنّاته',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11.sp,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16.h),
          Divider(color: colors.divider),
          SizedBox(height: 12.h),

          // Developer
          Text(
            'تطوير',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11.sp,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'م. سامر عبد العاطي',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'WhatsApp: +970593491741',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11.sp,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Debug Card ───

class _DebugCard extends StatefulWidget {
  final AppColorScheme colors;
  final String soundId;
  final String? customSoundUri;
  final bool hasExactAlarm;
  final bool batteryOptIgnored;
  final VoidCallback onRequestExactAlarm;
  final VoidCallback onRequestBatteryOpt;

  const _DebugCard({
    required this.colors,
    required this.soundId,
    this.customSoundUri,
    required this.hasExactAlarm,
    required this.batteryOptIgnored,
    required this.onRequestExactAlarm,
    required this.onRequestBatteryOpt,
  });

  @override
  State<_DebugCard> createState() => _DebugCardState();
}

class _DebugCardState extends State<_DebugCard> {
  bool _loading = false;
  bool _immediateLoading = false;
  bool? _immediateResult;
  int _scheduled = 0;
  int _pending = 0;
  int _fired = 0;
  List<String> _errors = [];
  bool _didSchedule = false;
  Timer? _autoRefresh;
  Timer? _countdown;
  DateTime? _nextFireTime;
  int _secondsLeft = 0;

  // Dart Timer test
  bool _timerTestRunning = false;
  int _timerFired = 0;
  int _timerTotal = 0;

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _countdown?.cancel();
    super.dispose();
  }

  void _startCountdown(DateTime nextFire) {
    _nextFireTime = nextFire;
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = _nextFireTime!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        // وقت الإطلاق — انتظر ثانية ثم تحقق من المعلّق
        setState(() => _secondsLeft = 0);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _didSchedule) {
            _refreshPending();
            // حرّك إلى الإشعار التالي (كل ١٠ ثواني)
            if (_pending > 1) {
              _startCountdown(_nextFireTime!.add(const Duration(seconds: 10)));
            } else {
              _countdown?.cancel();
            }
          }
        });
      } else {
        setState(() => _secondsLeft = remaining);
      }
    });
  }

  void _startAutoRefresh() {
    _autoRefresh?.cancel();
    _autoRefresh = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _didSchedule && _pending > 0) _refreshPending();
    });
  }

  Future<void> _startTimerTest() async {
    const count = 3;
    setState(() { _timerTestRunning = true; _timerFired = 0; _timerTotal = count; });
    await NotificationService.scheduleDebugDartTimers(
      soundId: widget.soundId,
      customSoundUri: widget.customSoundUri,
      intervalSeconds: 10,
      count: count,
      onFired: (fired) {
        if (mounted) setState(() { _timerFired = fired; if (fired >= count) _timerTestRunning = false; });
      },
    );
  }

  Future<void> _showImmediate() async {
    setState(() { _immediateLoading = true; _immediateResult = null; });
    final ok = await NotificationService.showDebugNow(
      soundId: widget.soundId,
      customSoundUri: widget.customSoundUri,
    );
    if (mounted) setState(() { _immediateLoading = false; _immediateResult = ok; });
  }

  Future<void> _schedule() async {
    setState(() { _loading = true; _errors = []; _fired = 0; _secondsLeft = 0; });
    try {
      final result = await NotificationService.scheduleDebugTest(
        soundId: widget.soundId,
        customSoundUri: widget.customSoundUri,
      );
      if (mounted) {
        setState(() {
          _scheduled = result.scheduled;
          _errors = result.errors;
          _didSchedule = true;
          _pending = result.scheduled;
          _fired = 0;
        });
        if (result.firstFireAt != null) {
          _startCountdown(result.firstFireAt!);
        }
        _startAutoRefresh();
      }
    } catch (e) {
      if (mounted) setState(() => _errors = ['خطأ: $e']);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshPending() async {
    final count = await NotificationService.getDebugPendingCount();
    if (mounted) setState(() { _pending = count; _fired = _scheduled - count; });
    if (count == 0) { _autoRefresh?.cancel(); _countdown?.cancel(); }
  }

  Future<void> _cancel() async {
    _autoRefresh?.cancel();
    _countdown?.cancel();
    setState(() => _loading = true);
    try {
      await NotificationService.cancelDebugTest();
      if (mounted) {
        setState(() {
          _didSchedule = false; _scheduled = 0; _pending = 0;
          _fired = 0; _errors = []; _secondsLeft = 0; _nextFireTime = null;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.6), width: 1.5),
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Header ───
          Row(
            children: [
              Icon(Icons.bug_report, color: Colors.orange, size: 20.r),
              SizedBox(width: 8.w),
              Expanded(
                child: Text('اختبار الإشعارات',
                    style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14.sp)),
              ),
              if (_didSchedule && _pending > 0)
                Text('↻ كل ٥ث', style: TextStyle(color: Colors.grey, fontSize: 10.sp)),
            ],
          ),
          SizedBox(height: 12.h),

          // ─── Permission status ───
          Row(children: [
            Icon(
              widget.hasExactAlarm ? Icons.alarm_on : Icons.alarm_off,
              size: 14.r,
              color: widget.hasExactAlarm ? Colors.green : Colors.red,
            ),
            SizedBox(width: 4.w),
            Text(
              widget.hasExactAlarm ? 'صلاحية التنبيه الدقيق ✓' : 'صلاحية التنبيه الدقيق ✗',
              style: TextStyle(
                fontSize: 10.sp,
                color: widget.hasExactAlarm ? Colors.green : Colors.red,
              ),
            ),
            if (!widget.hasExactAlarm) ...[
              SizedBox(width: 6.w),
              GestureDetector(
                onTap: widget.onRequestExactAlarm,
                child: Text('← اطلبها',
                    style: TextStyle(fontSize: 10.sp, color: Colors.blue,
                        decoration: TextDecoration.underline)),
              ),
            ],
            SizedBox(width: 12.w),
            Icon(
              widget.batteryOptIgnored ? Icons.battery_saver : Icons.battery_alert,
              size: 14.r,
              color: widget.batteryOptIgnored ? Colors.green : Colors.orange,
            ),
            SizedBox(width: 4.w),
            Text(
              widget.batteryOptIgnored ? 'بطارية مستثناة ✓' : 'بطارية غير مستثناة',
              style: TextStyle(
                fontSize: 10.sp,
                color: widget.batteryOptIgnored ? Colors.green : Colors.orange,
              ),
            ),
            if (!widget.batteryOptIgnored) ...[
              SizedBox(width: 6.w),
              GestureDetector(
                onTap: widget.onRequestBatteryOpt,
                child: Text('← اطلبها',
                    style: TextStyle(fontSize: 10.sp, color: Colors.blue,
                        decoration: TextDecoration.underline)),
              ),
            ],
          ]),
          SizedBox(height: 10.h),

          // ─── خطوة ١: اختبار فوري ───
          Text('١. اختبر الـ channel أولاً (فوري):',
              style: TextStyle(color: colors.textSecondary, fontSize: 11.sp)),
          SizedBox(height: 6.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _immediateLoading ? null : _showImmediate,
                  icon: _immediateLoading
                      ? SizedBox(width: 14.r, height: 14.r,
                          child: const CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.notifications_active, size: 16.r),
                  label: Text('إشعار فوري الآن', style: TextStyle(fontSize: 12.sp)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                  ),
                ),
              ),
              if (_immediateResult != null) ...[
                SizedBox(width: 8.w),
                Icon(
                  _immediateResult! ? Icons.check_circle : Icons.error,
                  color: _immediateResult! ? Colors.green : Colors.red,
                  size: 22.r,
                ),
              ],
            ],
          ),
          if (_immediateResult == true) ...[
            SizedBox(height: 4.h),
            Text('✓ Channel يعمل — الآن جدول الاختبار',
                style: TextStyle(color: Colors.green, fontSize: 11.sp)),
          ] else if (_immediateResult == false) ...[
            SizedBox(height: 4.h),
            Text('✗ Channel فشل — تحقق من صلاحية الإشعارات',
                style: TextStyle(color: Colors.red, fontSize: 11.sp)),
          ],

          SizedBox(height: 12.h),
          Divider(color: colors.textSecondary.withValues(alpha: 0.2)),
          SizedBox(height: 8.h),

          // ─── خطوة ٢: جدولة ───
          Text('٢. جدول كل ١٠ ثواني × ${NotificationService.kDebugCount} (يعمل بعد الإغلاق):',
              style: TextStyle(color: colors.textSecondary, fontSize: 11.sp)),
          SizedBox(height: 6.h),

          // ─── Counters ───
          if (_didSchedule) ...[
            Row(
              children: [
                _CounterBox(label: 'جُدول', value: _scheduled,
                    color: _scheduled == NotificationService.kDebugCount ? Colors.green : Colors.orange,
                    colors: colors),
                SizedBox(width: 6.w),
                _CounterBox(label: 'أُطلق ✓', value: _fired,
                    color: _fired > 0 ? Colors.green : Colors.grey,
                    highlight: _fired > 0, colors: colors),
                SizedBox(width: 6.w),
                _CounterBox(label: 'معلّق', value: _pending,
                    color: _pending > 0 ? Colors.blue : Colors.grey, colors: colors),
                SizedBox(width: 4.w),
                IconButton(
                  onPressed: _refreshPending,
                  icon: Icon(Icons.refresh, size: 18.r, color: colors.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 28.r, minHeight: 28.r),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            if (_errors.isNotEmpty)
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(_errors.first,
                    style: TextStyle(color: Colors.red, fontSize: 10.sp)),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fired == _scheduled
                        ? '✓ كل الإشعارات أُطلقت'
                        : _fired > 0
                            ? '⚡ يعمل! ($_fired أُطلق)'
                            : _secondsLeft > 0
                                ? '⏳ التالي بعد $_secondsLeft ث'
                                : '⏳ في انتظار الإطلاق...',
                    style: TextStyle(
                      color: _fired > 0
                          ? Colors.green
                          : _secondsLeft > 0
                              ? Colors.orange
                              : colors.textSecondary,
                      fontSize: 13.sp,
                      fontWeight: _secondsLeft > 0 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (_nextFireTime != null && _fired < _scheduled)
                    Text(
                      'وقت الإطلاق: ${_nextFireTime!.hour.toString().padLeft(2,'0')}:${_nextFireTime!.minute.toString().padLeft(2,'0')}:${_nextFireTime!.second.toString().padLeft(2,'0')}',
                      style: TextStyle(color: colors.textSecondary, fontSize: 10.sp),
                    ),
                ],
              ),
            SizedBox(height: 8.h),
          ],

          // ─── Dart Timer test ───
          SizedBox(height: 8.h),
          Divider(color: colors.textSecondary.withValues(alpha: 0.2)),
          SizedBox(height: 8.h),
          Text('٣. اختبار Dart Timer (تطبيق مفتوح — بدون AlarmManager):',
              style: TextStyle(color: colors.textSecondary, fontSize: 11.sp)),
          SizedBox(height: 6.h),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _timerTestRunning ? null : _startTimerTest,
                icon: _timerTestRunning
                    ? SizedBox(width: 14.r, height: 14.r,
                        child: const CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.timer, size: 16.r),
                label: Text(
                  _timerTestRunning
                      ? 'جارٍ... ($_timerFired/$_timerTotal)'
                      : _timerFired > 0
                          ? 'أعد التشغيل ($_timerFired/$_timerTotal ✓)'
                          : 'ابدأ Timer Test',
                  style: TextStyle(fontSize: 12.sp),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _timerFired > 0 ? Colors.green : Colors.purple,
                  side: BorderSide(color: _timerFired > 0 ? Colors.green : Colors.purple),
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                ),
              ),
            ),
          ]),
          if (_timerFired > 0 || _timerTestRunning) ...[
            SizedBox(height: 4.h),
            Text(
              _timerFired == _timerTotal
                  ? '✓ Timer يعمل → AlarmManager هو السبب (مشكلة MIUI)'
                  : '⏳ بانتظار $_timerFired/$_timerTotal إشعارات كل ١٠ث...',
              style: TextStyle(
                color: _timerFired == _timerTotal ? Colors.green : Colors.purple,
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          SizedBox(height: 8.h),

          // ─── MIUI fix ───
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '⚠ Xiaomi/MIUI: AlarmManager محجوب — يجب تفعيل "التشغيل التلقائي" لكي تعمل الإشعارات',
                  style: TextStyle(color: Colors.amber.shade800, fontSize: 10.sp),
                ),
                SizedBox(height: 6.h),
                FilledButton.icon(
                  onPressed: () => PlatformService.openMiuiAutostart(),
                  icon: Icon(Icons.open_in_new, size: 14.r),
                  label: Text('افتح إعدادات التشغيل التلقائي (MIUI)',
                      style: TextStyle(fontSize: 11.sp)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    padding: EdgeInsets.symmetric(vertical: 6.h),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 10.h),

          // ─── Buttons ───
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading ? null : _schedule,
                  icon: _loading
                      ? SizedBox(width: 16.r, height: 16.r,
                          child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(Icons.schedule, size: 18.r),
                  label: Text(_didSchedule ? 'إعادة الجدولة' : 'جدولة الاختبار',
                      style: TextStyle(fontSize: 13.sp)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                  ),
                ),
              ),
              if (_didSchedule) ...[
                SizedBox(width: 8.w),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _cancel,
                  icon: Icon(Icons.cancel_outlined, size: 18.r),
                  label: Text('إلغاء', style: TextStyle(fontSize: 13.sp)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CounterBox extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final AppColorScheme colors;
  final bool highlight;
  const _CounterBox({required this.label, required this.value, required this.color, required this.colors, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: highlight ? color.withValues(alpha: 0.12) : colors.bg,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: highlight ? color.withValues(alpha: 0.4) : Colors.transparent),
        ),
        child: Column(
          children: [
            Text('$value', style: TextStyle(color: color, fontSize: 20.sp, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: Colors.grey, fontSize: 9.sp), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─── Dhikr sound names ───

// أصوات الذكر فقط — الأذان في قائمة أصوات الصلاة
const _kDhikrSounds = [
  ('dhikr_tasbih',    'تسبيح 🤍'),
  ('dhikr_salawat',   'صلاة على النبي ﷺ 💛'),
  ('dhikr_istighfar', 'استغفار 💚'),
  ('beep_soft',       'تنبيه هادئ 🔔'),
];

// ─── Dhikr Sound Sheet ───

class _DhikrSoundSheet extends StatefulWidget {
  final String currentId;
  final ValueChanged<String> onPick;
  final String title;

  const _DhikrSoundSheet({
    required this.currentId,
    required this.onPick,
    this.title = 'صوت تذكير الذكر',
  });

  @override
  State<_DhikrSoundSheet> createState() => _DhikrSoundSheetState();
}

class _DhikrSoundSheetState extends State<_DhikrSoundSheet> {
  late String _selected;
  String? _playing;
  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _selected = widget.currentId;
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = null);
    });
  }

  @override
  void dispose() {
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  Future<void> _preview(String id) async {
    if (_playing == id) {
      await _player.stop();
      setState(() => _playing = null);
      return;
    }
    await _player.stop();
    setState(() => _playing = id);
    await _player.play(AssetSource('sounds/azkar/$id.mp3'));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        border: Border(top: BorderSide(color: AppColors.gold, width: 1.5)),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36.w, height: 4.h,
            decoration: BoxDecoration(
                color: Colors.grey.withAlpha(80),
                borderRadius: BorderRadius.circular(2.r)),
          ),
          SizedBox(height: 12.h),
          Text(widget.title,
              style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700)),
          SizedBox(height: 4.h),
          Text('اضغط ▶ للمعاينة',
              style: TextStyle(color: colors.textSecondary, fontSize: 11.sp)),
          SizedBox(height: 16.h),
          ..._kDhikrSounds.map((s) {
            final (id, name) = s;
            final isSelected = _selected == id;
            final isPlaying = _playing == id;
            return InkWell(
              onTap: () => setState(() => _selected = id),
              borderRadius: BorderRadius.circular(10.r),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22.r,
                      height: 22.r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : colors.textSecondary.withAlpha(80),
                            width: 1.5),
                      ),
                      child: isSelected
                          ? Icon(Icons.check, color: Colors.white, size: 14.r)
                          : null,
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Text(name,
                          style: TextStyle(
                              color: isSelected
                                  ? AppColors.primary
                                  : colors.textPrimary,
                              fontSize: 14.sp,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400)),
                    ),
                    GestureDetector(
                      onTap: () => _preview(id),
                      child: Container(
                        width: 36.r,
                        height: 36.r,
                        decoration: BoxDecoration(
                          color: isPlaying
                              ? AppColors.primary.withAlpha(20)
                              : colors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: isPlaying
                                  ? AppColors.primary
                                  : colors.divider),
                        ),
                        child: Icon(
                          isPlaying
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          color: isPlaying
                              ? AppColors.primary
                              : colors.textSecondary,
                          size: 18.r,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onPick(_selected);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r)),
              ),
              child: Text('حفظ الاختيار',
                  style: TextStyle(
                      fontSize: 15.sp, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dhikr Reminders Card ───

class _DhikrRemindersCard extends StatelessWidget {
  final AppColorScheme colors;
  final bool dhikrIstighfar, dhikrSalawat, dhikrTasbih, dhikrPostPrayer;
  final int dhikrIstighfarInterval, dhikrSalawatInterval, dhikrTasbihInterval;
  final String dhikrIstighfarSound, dhikrSalawatSound, dhikrTasbihSound;
  final void Function(String key, bool value) onToggle;
  final void Function(String intervalKey, int current) onPickInterval;
  final void Function(String soundKey, String currentId) onPickSound;

  const _DhikrRemindersCard({
    required this.colors,
    required this.dhikrIstighfar,
    required this.dhikrIstighfarInterval,
    required this.dhikrIstighfarSound,
    required this.dhikrSalawat,
    required this.dhikrSalawatInterval,
    required this.dhikrSalawatSound,
    required this.dhikrTasbih,
    required this.dhikrTasbihInterval,
    required this.dhikrTasbihSound,
    required this.dhikrPostPrayer,
    required this.onToggle,
    required this.onPickInterval,
    required this.onPickSound,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        children: [
          _DhikrTile(
            colors: colors,
            emoji: '💚',
            title: 'الاستغفار',
            arabicText: 'أستغفر الله العظيم وأتوب إليه',
            enabled: dhikrIstighfar,
            interval: dhikrIstighfarInterval,
            soundId: dhikrIstighfarSound,
            prefKey: AppConstants.keyDhikrIstighfar,
            intervalKey: AppConstants.keyDhikrIstighfarInterval,
            soundKey: AppConstants.keyDhikrIstighfarSound,
            onToggle: onToggle,
            onPickInterval: onPickInterval,
            onPickSound: onPickSound,
          ),
          _dhikrDivider(colors),
          _DhikrTile(
            colors: colors,
            emoji: '💛',
            title: 'الصلاة على النبي ﷺ',
            arabicText: 'اللهم صلِّ وسلِّم على نبينا محمد',
            enabled: dhikrSalawat,
            interval: dhikrSalawatInterval,
            soundId: dhikrSalawatSound,
            prefKey: AppConstants.keyDhikrSalawat,
            intervalKey: AppConstants.keyDhikrSalawatInterval,
            soundKey: AppConstants.keyDhikrSalawatSound,
            onToggle: onToggle,
            onPickInterval: onPickInterval,
            onPickSound: onPickSound,
          ),
          _dhikrDivider(colors),
          _DhikrTile(
            colors: colors,
            emoji: '🤍',
            title: 'التسبيح',
            arabicText: 'سبحان الله وبحمده سبحان الله العظيم',
            enabled: dhikrTasbih,
            interval: dhikrTasbihInterval,
            soundId: dhikrTasbihSound,
            prefKey: AppConstants.keyDhikrTasbih,
            intervalKey: AppConstants.keyDhikrTasbihInterval,
            soundKey: AppConstants.keyDhikrTasbihSound,
            onToggle: onToggle,
            onPickInterval: onPickInterval,
            onPickSound: onPickSound,
          ),
          _dhikrDivider(colors),
          // Post-prayer dhikr toggle
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            child: Row(
              children: [
                Text('🕌', style: TextStyle(fontSize: 22.sp)),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('أذكار بعد الصلاة',
                          style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600)),
                      Text('تذكير بعد كل صلاة مكتوبة',
                          style: TextStyle(
                              color: colors.textSecondary, fontSize: 11.sp)),
                    ],
                  ),
                ),
                Switch(
                  value: dhikrPostPrayer,
                  onChanged: (v) => onToggle(AppConstants.keyDhikrPostPrayer, v),
                  activeThumbColor: AppColors.primary,
                  activeTrackColor: AppColors.primary.withAlpha(180),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _dhikrDivider(AppColorScheme c) =>
      Divider(height: 0.5, color: c.divider, indent: 16.w, endIndent: 16.w);
}

class _DhikrTile extends StatelessWidget {
  final AppColorScheme colors;
  final String emoji, title, arabicText;
  final bool enabled;
  final int interval;
  final String soundId;
  final String prefKey, intervalKey, soundKey;
  final void Function(String, bool) onToggle;
  final void Function(String, int) onPickInterval;
  final void Function(String, String) onPickSound;

  const _DhikrTile({
    required this.colors,
    required this.emoji,
    required this.title,
    required this.arabicText,
    required this.enabled,
    required this.interval,
    required this.soundId,
    required this.prefKey,
    required this.intervalKey,
    required this.soundKey,
    required this.onToggle,
    required this.onPickInterval,
    required this.onPickSound,
  });

  String get _soundLabel {
    final found = _kDhikrSounds.where((s) => s.$1 == soundId).firstOrNull;
    return found?.$2 ?? 'تنبيه هادئ 🔔';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: TextStyle(fontSize: 22.sp)),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600)),
                    Text(arabicText,
                        style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 10.sp,
                            fontFamily: 'Cairo',
                            height: 1.4)),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: (v) => onToggle(prefKey, v),
                activeThumbColor: AppColors.primary,
                activeTrackColor: AppColors.primary.withAlpha(180),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          if (enabled) ...[
            SizedBox(height: 8.h),
            Padding(
              padding: EdgeInsets.only(right: 32.w),
              child: Wrap(
                spacing: 8.w,
                children: [
                  // ─── Interval chip ───
                  GestureDetector(
                    onTap: () => onPickInterval(intervalKey, interval),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: AppColors.primary.withAlpha(60)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.repeat_rounded, color: AppColors.primary, size: 13.r),
                          SizedBox(width: 4.w),
                          Text(
                            _SettingsPageState.dhikrIntervalLabel(interval),
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 3.w),
                          Icon(Icons.arrow_drop_down_rounded,
                              color: AppColors.primary, size: 15.r),
                        ],
                      ),
                    ),
                  ),
                  // ─── Sound chip ───
                  GestureDetector(
                    onTap: () => onPickSound(soundKey, soundId),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withAlpha(25),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: AppColors.gold.withAlpha(80)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.music_note_rounded,
                              color: AppColors.gold, size: 13.r),
                          SizedBox(width: 4.w),
                          Text(
                            _soundLabel,
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 3.w),
                          Icon(Icons.arrow_drop_down_rounded,
                              color: AppColors.gold, size: 15.r),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Dhikr Interval Bottom Sheet ───

class _DhikrIntervalSheet extends StatelessWidget {
  final int currentMinutes;
  const _DhikrIntervalSheet({required this.currentMinutes});

  static const _options = [
    (30,   'كل ٣٠ دقيقة'),
    (60,   'كل ساعة'),
    (120,  'كل ساعتين'),
    (180,  'كل ٣ ساعات'),
    (360,  'كل ٦ ساعات'),
    (1440, 'مرة يومياً (٩ صباحاً)'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        border: Border(top: BorderSide(color: AppColors.primary.withAlpha(80), width: 1.5)),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36.w, height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(80),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 12.h),
          Text('تكرار التذكير',
              style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700)),
          SizedBox(height: 4.h),
          Text('من ٧ صباحاً حتى ٩:٣٠ مساءً',
              style: TextStyle(color: colors.textSecondary, fontSize: 11.sp)),
          SizedBox(height: 16.h),
          ..._options.map((opt) {
            final (mins, label) = opt;
            final isSelected = currentMinutes == mins;
            return InkWell(
              onTap: () => Navigator.of(context).pop(mins),
              borderRadius: BorderRadius.circular(10.r),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 11.h),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: isSelected ? AppColors.primary : colors.textSecondary,
                      size: 22.r,
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Text(label,
                          style: TextStyle(
                            color: isSelected ? AppColors.primary : colors.textPrimary,
                            fontSize: 15.sp,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          )),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: AppColors.primary, size: 18.r),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MartyrRow extends StatelessWidget {
  final String name;
  final AppColorScheme colors;
  const _MartyrRow({required this.name, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('• ', style: TextStyle(color: AppColors.gold, fontSize: 12.sp)),
        Text(
          name,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
