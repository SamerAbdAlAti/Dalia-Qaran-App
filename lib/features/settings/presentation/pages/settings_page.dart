import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/state/font_scale_cubit.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_cubit.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _notifyFajr;
  late bool _notifyDhuhr;
  late bool _notifyAsr;
  late bool _notifyMaghrib;
  late bool _notifyIsha;

  @override
  void initState() {
    super.initState();
    _loadNotifyPrefs();
  }

  void _loadNotifyPrefs() {
    final p = sl<SharedPreferences>();
    setState(() {
      _notifyFajr = p.getBool(AppConstants.keyNotifyFajr) ?? true;
      _notifyDhuhr = p.getBool(AppConstants.keyNotifyDhuhr) ?? true;
      _notifyAsr = p.getBool(AppConstants.keyNotifyAsr) ?? true;
      _notifyMaghrib = p.getBool(AppConstants.keyNotifyMaghrib) ?? true;
      _notifyIsha = p.getBool(AppConstants.keyNotifyIsha) ?? true;
    });
  }

  Future<void> _setNotify(String key, bool value) async {
    await sl<SharedPreferences>().setBool(key, value);
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
                  SizedBox(height: 8.h),

                  // ─── حجم الخط ───
                  _SectionTitle(title: 'حجم الخط', colors: colors),
                  _FontScaleCard(colors: colors),
                  SizedBox(height: 8.h),

                  // ─── تنبيهات الصلاة ───
                  _SectionTitle(title: 'تنبيهات الصلاة', colors: colors),
                  _NotificationCard(
                    colors: colors,
                    notifyFajr: _notifyFajr,
                    notifyDhuhr: _notifyDhuhr,
                    notifyAsr: _notifyAsr,
                    notifyMaghrib: _notifyMaghrib,
                    notifyIsha: _notifyIsha,
                    onToggle: (key, value) {
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
                      _setNotify(key, value);
                    },
                  ),
                  SizedBox(height: 8.h),

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

// ─── Shared card decoration ───

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
              Icon(Icons.check_circle,
                  color: AppColors.primary, size: 20.r),
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
                  Icon(Icons.text_fields,
                      color: AppColors.primary, size: 22.r),
                  SizedBox(width: 14.w),
                  Text(
                    'حجم النص',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15.sp,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(state.scale * 100).round()}٪',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        context.read<FontScaleCubit>().decrease(),
                    icon: Icon(Icons.remove_circle_outline,
                        color: AppColors.primary, size: 24.r),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 36.r, minHeight: 36.r),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor:
                            AppColors.primary.withAlpha(40),
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
                    onPressed: () =>
                        context.read<FontScaleCubit>().increase(),
                    icon: Icon(Icons.add_circle_outline,
                        color: AppColors.primary, size: 24.r),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 36.r, minHeight: 36.r),
                  ),
                ],
              ),
              // Preview
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

// ─── Notification card ───

class _NotificationCard extends StatelessWidget {
  final AppColorScheme colors;
  final bool notifyFajr, notifyDhuhr, notifyAsr, notifyMaghrib, notifyIsha;
  final void Function(String key, bool value) onToggle;

  const _NotificationCard({
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
      ('الفجر', Icons.wb_twilight_outlined, AppConstants.keyNotifyFajr, notifyFajr),
      ('الظهر', Icons.wb_sunny_outlined, AppConstants.keyNotifyDhuhr, notifyDhuhr),
      ('العصر', Icons.wb_sunny_outlined, AppConstants.keyNotifyAsr, notifyAsr),
      ('المغرب', Icons.wb_twighlight, AppConstants.keyNotifyMaghrib, notifyMaghrib),
      ('العشاء', Icons.nights_stay_outlined, AppConstants.keyNotifyIsha, notifyIsha),
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
                  'اختر الصلوات التي تريد تنبيهاً لها',
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
                _PrayerNotifyTile(
                  name: name,
                  icon: icon,
                  key: ValueKey(key),
                  prefKey: key,
                  value: value,
                  colors: colors,
                  onToggle: onToggle,
                ),
                if (i < prayers.length - 1)
                  Divider(
                      height: 0.5,
                      color: colors.divider,
                      indent: 56.w),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _PrayerNotifyTile extends StatelessWidget {
  final String name;
  final IconData icon;
  final String prefKey;
  final bool value;
  final AppColorScheme colors;
  final void Function(String, bool) onToggle;

  const _PrayerNotifyTile({
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
            child: Text(
              name,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 15.sp,
              ),
            ),
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
            child: Icon(Icons.menu_book_rounded,
                color: Colors.white, size: 28.r),
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
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12.sp,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'الإصدار 1.0.0',
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
