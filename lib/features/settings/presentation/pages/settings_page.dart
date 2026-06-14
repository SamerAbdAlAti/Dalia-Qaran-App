import 'package:audioplayers/audioplayers.dart';
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
  late bool _remAdhkarMorning, _remAdhkarEvening, _remFajrSunnah,
      _remQiyam, _remDuha, _remQuran, _remSalahAnnabi;
  late String _remAdhkarMorningTime, _remAdhkarEveningTime,
      _remDuhaTime, _remQuranTime, _remSalahAnnabiTime;
  late int _remFajrSunnahMin;

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

                  // ─── عن التطبيق ───
                  _SectionTitle(title: 'عن التطبيق', colors: colors),
                  _AboutCard(colors: colors),
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

// ─── About card ───

class _AboutCard extends StatelessWidget {
  final AppColorScheme colors;
  const _AboutCard({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(colors),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      child: Column(
        children: [
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
            child:
                Icon(Icons.menu_book_rounded, color: Colors.white, size: 28.r),
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
        ],
      ),
    );
  }
}
