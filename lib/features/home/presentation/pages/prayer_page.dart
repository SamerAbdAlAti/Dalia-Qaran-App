import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/utils/hijri_date.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/prayer_times_entity.dart';
import '../cubit/home_cubit.dart';

class PrayerPage extends StatelessWidget {
  const PrayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          if (state is HomeLoading || state is HomeInitial) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (state is HomeLoaded) {
            return _PrayerContent(
                prayerTimes: state.prayerTimes, now: state.now);
          }
          return const Center(
            child: Text('تعذّر تحميل أوقات الصلاة',
                style: TextStyle(color: AppColors.primary)),
          );
        },
      ),
    );
  }
}

class _PrayerContent extends StatelessWidget {
  final PrayerTimesEntity prayerTimes;
  final DateTime now;

  const _PrayerContent({required this.prayerTimes, required this.now});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => context.read<HomeCubit>().refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _PrayerHeader(prayerTimes: prayerTimes, now: now)),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
            sliver: SliverToBoxAdapter(
              child: _FullPrayerList(prayerTimes: prayerTimes, now: now),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerHeader extends StatelessWidget {
  final PrayerTimesEntity prayerTimes;
  final DateTime now;

  const _PrayerHeader({required this.prayerTimes, required this.now});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
          child: Column(
            children: [
              Text(
                'أوقات الصلاة',
                style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
              SizedBox(height: 4.h),
              Text(
                '${DateFormat('EEEE', 'ar').format(now)}، ${HijriDate.format(now)}',
                style: TextStyle(
                    fontSize: 13.sp, color: Colors.white.withAlpha(180)),
              ),
              if (prayerTimes.cityName.isNotEmpty) ...[
                SizedBox(height: 4.h),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 12.r, color: Colors.white.withAlpha(160)),
                    SizedBox(width: 3.w),
                    Text(prayerTimes.cityName,
                        style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.white.withAlpha(160))),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

typedef _PrayerEntry = ({String name, DateTime time, IconData icon});

class _FullPrayerList extends StatelessWidget {
  final PrayerTimesEntity prayerTimes;
  final DateTime now;

  const _FullPrayerList({required this.prayerTimes, required this.now});

  @override
  Widget build(BuildContext context) {
    final prayers = <_PrayerEntry>[
      (name: 'الفجر (أذان أول)', time: prayerTimes.fajrFirst, icon: Icons.bedtime_outlined),
      (name: 'الفجر (أذان ثاني)', time: prayerTimes.fajr, icon: Icons.wb_twilight_rounded),
      (name: 'الشروق', time: prayerTimes.sunrise, icon: Icons.wb_sunny_outlined),
      (name: 'الظهر', time: prayerTimes.dhuhr, icon: Icons.wb_sunny_rounded),
      (name: 'العصر', time: prayerTimes.asr, icon: Icons.light_mode_outlined),
      (name: 'المغرب', time: prayerTimes.maghrib, icon: Icons.nightlight_round),
      (name: 'العشاء', time: prayerTimes.isha, icon: Icons.dark_mode_outlined),
    ];
    final nextIdx = prayers.indexWhere((p) => p.time.isAfter(now));
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Column(
          children: [
            ...List.generate(prayers.length, (i) {
              final p = prayers[i];
              final isPast = nextIdx >= 0 ? i < nextIdx : true;
              final isNext = i == nextIdx;
              return _PrayerRow(
                name: p.name,
                time: p.time,
                icon: p.icon,
                isPast: isPast,
                isNext: isNext,
                showDivider: i < prayers.length - 1,
                colors: colors,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _PrayerRow extends StatelessWidget {
  final String name;
  final DateTime time;
  final IconData icon;
  final bool isPast;
  final bool isNext;
  final bool showDivider;
  final AppColorScheme colors;

  const _PrayerRow({
    required this.name,
    required this.time,
    required this.icon,
    required this.isPast,
    required this.isNext,
    required this.showDivider,
    required this.colors,
  });

  String _countdown(DateTime now) {
    final diff = time.difference(now);
    if (!diff.isNegative) {
      final h = diff.inHours;
      final m = diff.inMinutes.remainder(60);
      if (h > 0) {
        return 'بعد ${toArabicNumerals(h.toString())} س و ${toArabicNumerals(m.toString())} د';
      }
      return 'بعد ${toArabicNumerals(m.toString())} د';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: isNext ? AppColors.primary.withAlpha(18) : null,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Row(
            children: [
              Container(
                width: 38.r,
                height: 38.r,
                decoration: BoxDecoration(
                  color: isNext
                      ? AppColors.primary.withAlpha(25)
                      : isPast
                          ? colors.surface
                          : colors.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 18.r,
                  color: isNext
                      ? AppColors.primary
                      : isPast
                          ? colors.textSecondary
                          : colors.textSecondary,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight:
                            isNext ? FontWeight.w700 : FontWeight.w500,
                        color: isNext
                            ? AppColors.primary
                            : isPast
                                ? colors.textSecondary
                                : colors.textPrimary,
                      ),
                    ),
                    if (isNext)
                      Text(
                        _countdown(now),
                        style: TextStyle(
                            fontSize: 11.sp, color: AppColors.primary),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatPrayerTime(time),
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight:
                          isNext ? FontWeight.w700 : FontWeight.w500,
                      color: isNext
                          ? AppColors.gold
                          : isPast
                              ? colors.textSecondary
                              : colors.textPrimary,
                    ),
                  ),
                  if (isPast)
                    Icon(Icons.check_circle_outline,
                        size: 14.r,
                        color: AppColors.primary.withAlpha(120)),
                ],
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, thickness: 1, color: colors.divider, indent: 66.w),
      ],
    );
  }
}
