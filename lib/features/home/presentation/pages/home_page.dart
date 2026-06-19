import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/daily_verses.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/utils/hijri_date.dart';
import '../../domain/entities/prayer_times_entity.dart';
import '../cubit/home_cubit.dart';
import '../../../adhkar/domain/entities/zikr_entity.dart';
import '../../../adhkar/presentation/pages/zikr_reader_page.dart';

// ─── Page ───

class HomePage extends StatelessWidget {
  final ValueChanged<int>? onNavigateTo;
  const HomePage({super.key, this.onNavigateTo});

  @override
  Widget build(BuildContext context) {
    return _HomeScaffold(onNavigateTo: onNavigateTo);
  }
}

// ─── Scaffold ───

class _HomeScaffold extends StatelessWidget {
  final ValueChanged<int>? onNavigateTo;
  const _HomeScaffold({this.onNavigateTo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          if (state is HomeLoading || state is HomeInitial) {
            return _LoadingView(onPickCity: () => showCityPicker(context));
          }
          if (state is HomeLocationDisabled) {
            return const _LocationDisabledView();
          }
          if (state is HomeError) {
            return _ErrorView(message: state.message);
          }
          if (state is HomeLoaded) {
            return _LoadedView(
              prayerTimes: state.prayerTimes,
              now: state.now,
              onNavigateTo: onNavigateTo,
            );
          }
          return _LoadingView(onPickCity: () => showCityPicker(context));
        },
      ),
    );
  }
}

// ─── Loading ───

class _LoadingView extends StatelessWidget {
  final VoidCallback onPickCity;
  const _LoadingView({required this.onPickCity});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16.h),
              Text(
                'جارٍ تحديد موقعك...',
                style: TextStyle(fontSize: 14.sp, color: colors.textSecondary),
              ),
              SizedBox(height: 28.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onPickCity,
                  icon: const Icon(Icons.location_city_outlined),
                  label: const Text('تحديد المدينة يدوياً'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: EdgeInsets.symmetric(vertical: 13.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Error ───

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.gps_off, size: 48.r, color: colors.textSecondary),
              SizedBox(height: 16.h),
              Text(
                message,
                style: TextStyle(fontSize: 14.sp, color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.read<HomeCubit>().load(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 13.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => showCityPicker(context),
                  icon: const Icon(Icons.location_city_outlined),
                  label: const Text('تحديد المدينة يدوياً'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: EdgeInsets.symmetric(vertical: 13.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Location Disabled ───

class _LocationDisabledView extends StatelessWidget {
  const _LocationDisabledView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80.r,
                height: 80.r,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_off_outlined,
                  size: 40.r,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'الموقع الجغرافي معطّل',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'يحتاج التطبيق إلى الموقع الجغرافي لحساب أوقات الصلاة.\nيرجى تفعيل الموقع الجغرافي في إعدادات الهاتف.',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: colors.textSecondary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 28.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async => Geolocator.openLocationSettings(),
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('فتح إعدادات الموقع'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              TextButton(
                onPressed: () => context.read<HomeCubit>().load(),
                child: Text(
                  'تحديث بعد التفعيل',
                  style: TextStyle(fontSize: 14.sp, color: AppColors.primary),
                ),
              ),
              TextButton(
                onPressed: () => showCityPicker(context),
                child: Text(
                  'تحديد المدينة يدوياً',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Loaded ───

class _LoadedView extends StatelessWidget {
  final PrayerTimesEntity prayerTimes;
  final DateTime now;
  final ValueChanged<int>? onNavigateTo;

  const _LoadedView({
    required this.prayerTimes,
    required this.now,
    this.onNavigateTo,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => context.read<HomeCubit>().refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _GreenHeader(prayerTimes: prayerTimes, now: now),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 0),
            sliver: SliverToBoxAdapter(
              child: _QuickAccessRow(onNavigateTo: onNavigateTo),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
            sliver: const SliverToBoxAdapter(child: _VerseOfDayCard()),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
            sliver: const SliverToBoxAdapter(child: _AdhkarCard()),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
            sliver: SliverToBoxAdapter(
              child: _TodayPrayerTimesCard(prayerTimes: prayerTimes, now: now),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 32.h)),
        ],
      ),
    );
  }
}

// ─── Green Header ───

class _GreenHeader extends StatelessWidget {
  final PrayerTimesEntity prayerTimes;
  final DateTime now;

  const _GreenHeader({required this.prayerTimes, required this.now});

  ({String name, DateTime time, DateTime? prev})? get _nextPrayer {
    final prayers = [
      ('الفجر (أذان أول)', prayerTimes.fajrFirst),
      ('الفجر', prayerTimes.fajr),
      ('الظهر', prayerTimes.dhuhr),
      ('العصر', prayerTimes.asr),
      ('المغرب', prayerTimes.maghrib),
      ('العشاء', prayerTimes.isha),
    ];
    for (int i = 0; i < prayers.length; i++) {
      if (prayers[i].$2.isAfter(now)) {
        return (
          name: prayers[i].$1,
          time: prayers[i].$2,
          prev: i > 0 ? prayers[i - 1].$2 : null,
        );
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final next = _nextPrayer;
    final weekday = DateFormat('EEEE', 'ar').format(now);
    final hijri = HijriDate.format(now);

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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '$weekday، $hijri',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: Colors.white.withAlpha(180),
                ),
              ),
              SizedBox(height: 6.h),
              if (prayerTimes.cityName.isNotEmpty) ...[
                SizedBox(height: 4.h),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 12.r,
                      color: Colors.white.withAlpha(160),
                    ),
                    SizedBox(width: 3.w),
                    Text(
                      prayerTimes.cityName,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.white.withAlpha(160),
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: 18.h),
              _NextPrayerBox(next: next, now: now),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Next Prayer Box ───

class _NextPrayerBox extends StatelessWidget {
  final ({String name, DateTime time, DateTime? prev})? next;
  final DateTime now;

  const _NextPrayerBox({required this.next, required this.now});

  double _progress() {
    final n = next;
    if (n == null || n.prev == null) return 0;
    final total = n.time.difference(n.prev!).inSeconds;
    if (total <= 0) return 0;
    final elapsed = now.difference(n.prev!).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  String _countdown() {
    final n = next;
    if (n == null) return '';
    final diff = n.time.difference(now);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    if (h > 0) {
      return 'بعد ${toArabicNumerals(h.toString())} س و ${toArabicNumerals(m.toString())} د';
    }
    return 'بعد ${toArabicNumerals(m.toString())} دقيقة';
  }

  @override
  Widget build(BuildContext context) {
    final n = next;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(50),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withAlpha(30), width: 1),
      ),
      child: n == null
          ? _AllDoneTile()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatPrayerTime(n.time),
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold,
                        height: 1,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'الصلاة القادمة',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.white.withAlpha(160),
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          n.name,
                          style: TextStyle(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: LinearProgressIndicator(
                    value: _progress(),
                    backgroundColor: Colors.white.withAlpha(40),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.gold,
                    ),
                    minHeight: 5.h,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  _countdown(),
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.white.withAlpha(200),
                  ),
                ),
              ],
            ),
    );
  }
}

class _AllDoneTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.nights_stay_outlined,
          size: 24.r,
          color: Colors.white.withAlpha(180),
        ),
        SizedBox(width: 10.w),
        Text(
          'انتهت صلوات اليوم — ابدأ غداً بالفجر',
          style: TextStyle(fontSize: 14.sp, color: Colors.white.withAlpha(200)),
        ),
      ],
    );
  }
}

// ─── Quick Access Row ───

class _QuickAccessRow extends StatelessWidget {
  final ValueChanged<int>? onNavigateTo;
  const _QuickAccessRow({this.onNavigateTo});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'وصول سريع',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            _QuickCard(
              label: 'القرآن',
              icon: Icons.menu_book_rounded,
              iconBg: AppColors.primary.withAlpha(25),
              iconColor: AppColors.primary,
              onTap: () => onNavigateTo?.call(1),
            ),
            SizedBox(width: 12.w),
            _QuickCard(
              label: 'الصلاة',
              icon: Icons.access_time_rounded,
              iconBg: AppColors.gold.withAlpha(35),
              iconColor: AppColors.gold,
              onTap: () => onNavigateTo?.call(2),
            ),
            SizedBox(width: 12.w),
            _QuickCard(
              label: 'القبلة',
              icon: Icons.explore_rounded,
              iconBg: Colors.blue.withAlpha(25),
              iconColor: Colors.blue.shade600,
              onTap: () => onNavigateTo?.call(3),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;

  const _QuickCard({
    required this.label,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(14.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48.r,
                height: 48.r,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(icon, color: iconColor, size: 26.r),
              ),
              SizedBox(height: 8.h),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Verse Of Day ───

class _VerseOfDayCard extends StatelessWidget {
  const _VerseOfDayCard();

  // كانت هذه قائمة محلية مستقلة عن قائمة widget_service.dart (نفس الطول،
  // محتوى مختلف الترتيب) فكانت "آية اليوم" تختلف بين داخل التطبيق والـ
  // App Widget لنفس اليوم — استبدلت بمصدر واحد مشترك (dailyVerses).
  static final _verses = dailyVerses;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dayIndex = DateTime.now().day % _verses.length;
    final (text, surahName, ayahId) = _verses[dayIndex];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'آية اليوم',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.gold.withAlpha(30),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  'سورة $surahName — ${toArabicNumerals(ayahId.toString())}',
                  style: TextStyle(fontSize: 11.sp, color: AppColors.gold),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Text(
            '﴿ $text ﴾',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'ScheherazadeNew',
              fontSize: 20.sp,
              color: colors.textPrimary,
              height: 2.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Adhkar Card ───

class _AdhkarCard extends StatelessWidget {
  const _AdhkarCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 8.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'أذكاري اليومية',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.divider),
          Padding(
            padding: EdgeInsets.all(12.r),
            child: Row(
              children: [
                _AdhkarButton(
                  label: 'أذكار الصباح',
                  icon: Icons.wb_sunny_outlined,
                  color: const Color(0xFFE67E22),
                  bg: const Color(0xFFFFF3E0),
                  category: ZikrCategory.morning,
                ),
                SizedBox(width: 8.w),
                _AdhkarButton(
                  label: 'أذكار المساء',
                  icon: Icons.nights_stay_outlined,
                  color: const Color(0xFF5C6BC0),
                  bg: const Color(0xFFE8EAF6),
                  category: ZikrCategory.evening,
                ),
                SizedBox(width: 8.w),
                _AdhkarButton(
                  label: 'بعد الصلاة',
                  icon: Icons.mosque_outlined,
                  color: AppColors.primary,
                  bg: const Color(0xFFE8F5E9),
                  category: ZikrCategory.afterPrayer,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdhkarButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  final ZikrCategory category;

  const _AdhkarButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ZikrReaderPage(category: category)),
        ),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14.h),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.r,
                height: 40.r,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20.r),
              ),
              SizedBox(height: 8.h),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Today Prayer Times Card (compact) ───

class _TodayPrayerTimesCard extends StatelessWidget {
  final PrayerTimesEntity prayerTimes;
  final DateTime now;

  const _TodayPrayerTimesCard({required this.prayerTimes, required this.now});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final prayers = [
      ('أذان أول', prayerTimes.fajrFirst),
      ('أذان ثاني', prayerTimes.fajr),
      ('الظهر', prayerTimes.dhuhr),
      ('العصر', prayerTimes.asr),
      ('المغرب', prayerTimes.maghrib),
      ('العشاء', prayerTimes.isha),
    ];
    final nextIdx = prayers.indexWhere((p) => p.$2.isAfter(now));

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 8.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'أوقات الصلاة اليوم',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.divider),
          GridView.builder(
            padding: EdgeInsets.all(12.r),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.2,
              crossAxisSpacing: 6.w,
              mainAxisSpacing: 6.h,
            ),
            itemCount: prayers.length,
            itemBuilder: (context, i) {
              final isNext = i == nextIdx;
              final isPast = nextIdx >= 0 ? i < nextIdx : true;
              final (name, time) = prayers[i];
              return _PrayerChip(
                name: name,
                time: time,
                isNext: isNext,
                isPast: isPast,
                colors: colors,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PrayerChip extends StatelessWidget {
  final String name;
  final DateTime time;
  final bool isNext;
  final bool isPast;
  final AppColorScheme colors;

  const _PrayerChip({
    required this.name,
    required this.time,
    required this.isNext,
    required this.isPast,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isNext
        ? AppColors.primary
        : isPast
        ? colors.textSecondary
        : colors.textPrimary;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: isNext ? AppColors.primary.withAlpha(18) : colors.surface,
        borderRadius: BorderRadius.circular(10.r),
        border: isNext
            ? Border.all(color: AppColors.primary.withAlpha(60), width: 1)
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              formatPrayerTime(time),
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
                color: isNext ? AppColors.gold : textColor,
              ),
            ),
          ),
          Text(
            name,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── City Picker ───

void showCityPicker(BuildContext context) {
  final cubit = context.read<HomeCubit>();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CityPickerSheet(cubit: cubit),
  );
}

class CityPickerSheet extends StatelessWidget {
  final HomeCubit cubit;
  const CityPickerSheet({super.key, required this.cubit});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // ListTile paints its background/ink splashes on the nearest Material
    // ancestor — a plain Container with a background color hides them.
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      child: Material(
        color: colors.card,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 32.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'اختر مدينتك',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              SizedBox(height: 12.h),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _kCities.length,
                  separatorBuilder: (context, i) =>
                      Divider(height: 1, color: colors.divider),
                  itemBuilder: (_, i) {
                    final city = _kCities[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.location_on_outlined,
                        size: 20.r,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        city.name,
                        style: TextStyle(
                          fontSize: 15.sp,
                          color: colors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        city.country,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: colors.textSecondary,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        cubit.setCity(city.lat, city.lng, city.name);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Cities Data ───

class _City {
  final String name;
  final String country;
  final double lat;
  final double lng;
  const _City(this.name, this.country, this.lat, this.lng);
}

const _kCities = [
  _City('مكة المكرمة', 'المملكة العربية السعودية', 21.3891, 39.8579),
  _City('المدينة المنورة', 'المملكة العربية السعودية', 24.5247, 39.5692),
  _City('الرياض', 'المملكة العربية السعودية', 24.6877, 46.7219),
  _City('جدة', 'المملكة العربية السعودية', 21.4858, 39.1925),
  _City('دبي', 'الإمارات العربية المتحدة', 25.2048, 55.2708),
  _City('أبوظبي', 'الإمارات العربية المتحدة', 24.4539, 54.3773),
  _City('الكويت', 'الكويت', 29.3759, 47.9774),
  _City('الدوحة', 'قطر', 25.2854, 51.5310),
  _City('المنامة', 'البحرين', 26.2285, 50.5860),
  _City('مسقط', 'سلطنة عُمان', 23.5880, 58.3829),
  _City('القاهرة', 'مصر', 30.0444, 31.2357),
  _City('الإسكندرية', 'مصر', 31.2001, 29.9187),
  _City('بيروت', 'لبنان', 33.8938, 35.5018),
  _City('عمّان', 'الأردن', 31.9539, 35.9106),
  _City('دمشق', 'سوريا', 33.5138, 36.2765),
  _City('بغداد', 'العراق', 33.3152, 44.3661),
  _City('صنعاء', 'اليمن', 15.3694, 44.1910),
  _City('الخرطوم', 'السودان', 15.5007, 32.5599),
  _City('طرابلس', 'ليبيا', 32.9022, 13.1787),
  _City('تونس', 'تونس', 36.8065, 10.1815),
  _City('الجزائر', 'الجزائر', 36.7372, 3.0865),
  _City('الرباط', 'المغرب', 34.0209, -6.8416),
  _City('الدار البيضاء', 'المغرب', 33.5731, -7.5898),
  _City('غزة', 'فلسطين', 31.5017, 34.4668),
  _City('القدس', 'فلسطين', 31.7683, 35.2137),
  _City('رام الله', 'فلسطين', 31.9038, 35.2034),
  _City('نابلس', 'فلسطين', 32.2211, 35.2544),
  _City('الخليل', 'فلسطين', 31.5293, 35.0998),
  _City('جنين', 'فلسطين', 32.4611, 35.2956),
  _City('طولكرم', 'فلسطين', 32.3100, 35.0282),
  _City('أريحا', 'فلسطين', 31.8611, 35.4610),
  _City('بيت لحم', 'فلسطين', 31.7054, 35.2024),
  _City('الناصرة', 'فلسطين', 32.6996, 35.3035),
  _City('حيفا', 'فلسطين', 32.7940, 34.9896),
  _City('إسطنبول', 'تركيا', 41.0082, 28.9784),
  _City('لندن', 'المملكة المتحدة', 51.5074, -0.1278),
  _City('باريس', 'فرنسا', 48.8566, 2.3522),
  _City('برلين', 'ألمانيا', 52.5200, 13.4050),
  _City('نيويورك', 'الولايات المتحدة', 40.7128, -74.0060),
];
