import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../domain/entities/zikr_entity.dart';
import '../cubit/adhkar_reader_cubit.dart';

// ─── Category theme ───

class _CategoryTheme {
  final Color primary;
  final Color light;
  final Color bg;
  final IconData icon;

  const _CategoryTheme({
    required this.primary,
    required this.light,
    required this.bg,
    required this.icon,
  });
}

_CategoryTheme _themeFor(ZikrCategory cat) => switch (cat) {
      ZikrCategory.morning => const _CategoryTheme(
          primary: Color(0xFFE67E22),
          light: Color(0xFFFFF3E0),
          bg: Color(0xFFFFF8F0),
          icon: Icons.wb_sunny_outlined,
        ),
      ZikrCategory.evening => const _CategoryTheme(
          primary: Color(0xFF5C6BC0),
          light: Color(0xFFE8EAF6),
          bg: Color(0xFFF3F4FB),
          icon: Icons.nights_stay_outlined,
        ),
      ZikrCategory.afterPrayer => const _CategoryTheme(
          primary: AppColors.primary,
          light: Color(0xFFE8F5E9),
          bg: Color(0xFFF1F8F1),
          icon: Icons.mosque_outlined,
        ),
    };

// ─── Entry Point ───

class ZikrReaderPage extends StatelessWidget {
  final ZikrCategory category;
  const ZikrReaderPage({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AdhkarReaderCubit>()..load(category),
      child: _ZikrReaderView(category: category),
    );
  }
}

// ─── Main View ───

class _ZikrReaderView extends StatelessWidget {
  final ZikrCategory category;
  const _ZikrReaderView({required this.category});

  @override
  Widget build(BuildContext context) {
    final theme = _themeFor(category);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<AdhkarReaderCubit, AdhkarReaderState>(
      listenWhen: (_, curr) =>
          curr is AdhkarReaderActive && curr.justCompleted,
      listener: (ctx, _) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (ctx.mounted) ctx.read<AdhkarReaderCubit>().next();
        });
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor:
              isDark ? context.colors.bg : theme.bg,
          body: switch (state) {
            AdhkarReaderLoading() || AdhkarReaderInitial() =>
              const Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
            AdhkarReaderError(:final message) => _ErrorBody(message: message),
            AdhkarReaderComplete(:final adhkar) => _CompleteBody(
                category: category,
                theme: theme,
                total: adhkar.length,
              ),
            AdhkarReaderActive() => _ActiveBody(
                state: state,
                category: category,
                theme: theme,
              ),
            _ => const SizedBox.shrink(),
          },
        );
      },
    );
  }
}

// ─── Active Body ───

class _ActiveBody extends StatelessWidget {
  final AdhkarReaderActive state;
  final ZikrCategory category;
  final _CategoryTheme theme;

  const _ActiveBody({
    required this.state,
    required this.category,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      children: [
        // ── Header ──
        _Header(state: state, category: category, theme: theme),

        // ── Session Progress Bar ──
        TweenAnimationBuilder<double>(
          tween: Tween(
            begin: 0,
            end: state.completedCount / state.adhkar.length,
          ),
          duration: const Duration(milliseconds: 400),
          builder: (_, val, child) => LinearProgressIndicator(
            value: val,
            minHeight: 3,
            backgroundColor: colors.divider,
            valueColor: AlwaysStoppedAnimation(theme.primary),
          ),
        ),

        // ── Content ──
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 8.h),
            child: Column(
              children: [
                // Zikr text card
                _ZikrCard(state: state, theme: theme),
                SizedBox(height: 20.h),

                // Counter
                _CounterWidget(state: state, theme: theme),
                SizedBox(height: 20.h),

                // Tap button
                _TapButton(state: state, theme: theme),
                SizedBox(height: 8.h),
              ],
            ),
          ),
        ),

        // ── Navigation ──
        _NavigationBar(state: state, theme: theme),
        SizedBox(height: MediaQuery.paddingOf(context).bottom + 8.h),
      ],
    );
  }
}

// ─── Header ───

class _Header extends StatelessWidget {
  final AdhkarReaderActive state;
  final ZikrCategory category;
  final _CategoryTheme theme;

  const _Header(
      {required this.state,
      required this.category,
      required this.theme});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(4.w, 8.h, 16.w, 12.h),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              color: colors.textPrimary,
              onPressed: () => Navigator.pop(context),
            ),
            SizedBox(width: 4.w),
            Icon(theme.icon, color: theme.primary, size: 22.r),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                category.label,
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ),
            // Progress badge
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: theme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                '${toArabicNumerals((state.currentIndex + 1).toString())} / ${toArabicNumerals(state.adhkar.length.toString())}',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: theme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Zikr Card ───

class _ZikrCard extends StatelessWidget {
  final AdhkarReaderActive state;
  final _CategoryTheme theme;

  const _ZikrCard({required this.state, required this.theme});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final zikr = state.current;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(zikr.id),
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: colors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Text area
            Padding(
              padding:
                  EdgeInsets.fromLTRB(20.w, 28.h, 20.w, 20.h),
              child: Text(
                zikr.text,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'ScheherazadeNew',
                  fontSize: 22.sp,
                  color: colors.textPrimary,
                  height: 2.1,
                ),
              ),
            ),

            // Divider + meta
            if (zikr.source != null || zikr.benefit != null) ...[
              Divider(height: 1, color: colors.divider),
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (zikr.source != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            zikr.source!,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: theme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Icon(Icons.menu_book_outlined,
                              size: 14.r, color: theme.primary),
                        ],
                      ),
                    if (zikr.benefit != null) ...[
                      SizedBox(height: 6.h),
                      Text(
                        zikr.benefit!,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: colors.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Counter Widget ───

class _CounterWidget extends StatelessWidget {
  final AdhkarReaderActive state;
  final _CategoryTheme theme;

  const _CounterWidget({required this.state, required this.theme});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final current = state.currentCount;
    final total = state.current.repeatCount;
    final isDone = state.isDone;
    final color = isDone ? AppColors.success : theme.primary;

    if (total <= 10) {
      // Dot indicators
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(total, (i) {
              final filled = i < current;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.symmetric(horizontal: 4.w),
                width: filled ? 12.r : 10.r,
                height: filled ? 12.r : 10.r,
                decoration: BoxDecoration(
                  color: filled ? color : Colors.transparent,
                  shape: BoxShape.circle,
                  border: filled
                      ? null
                      : Border.all(
                          color: colors.divider,
                          width: 1.5,
                        ),
                ),
              );
            }),
          ),
          SizedBox(height: 8.h),
          Text(
            isDone
                ? 'أُنجز ✓'
                : '${toArabicNumerals(current.toString())} من ${toArabicNumerals(total.toString())}',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: isDone ? AppColors.success : colors.textSecondary,
            ),
          ),
        ],
      );
    }

    // Circular progress for larger counts
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 80.r,
          height: 80.r,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80.r,
                height: 80.r,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: current / total),
                  duration: const Duration(milliseconds: 300),
                  builder: (_, val, child) => CircularProgressIndicator(
                    value: val,
                    strokeWidth: 7,
                    backgroundColor: colors.divider,
                    valueColor: AlwaysStoppedAnimation(color),
                    strokeCap: StrokeCap.round,
                  ),
                ),
              ),
              isDone
                  ? Icon(Icons.check_rounded, color: AppColors.success, size: 30.r)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          toArabicNumerals(current.toString()),
                          style: TextStyle(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                            height: 1,
                          ),
                        ),
                        Text(
                          'من ${toArabicNumerals(total.toString())}',
                          style: TextStyle(
                              fontSize: 10.sp,
                              color: colors.textSecondary),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Tap Button ───

class _TapButton extends StatefulWidget {
  final AdhkarReaderActive state;
  final _CategoryTheme theme;

  const _TapButton({required this.state, required this.theme});

  @override
  State<_TapButton> createState() => _TapButtonState();
}

class _TapButtonState extends State<_TapButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() async {
    await _controller.forward();
    await _controller.reverse();
    if (mounted) context.read<AdhkarReaderCubit>().tap();
  }

  @override
  Widget build(BuildContext context) {
    final isDone = widget.state.isDone;
    final color = isDone ? AppColors.success : widget.theme.primary;

    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTap: isDone ? null : _onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          height: 60.h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isDone ? Icons.check_circle_outline : Icons.touch_app_outlined,
                color: Colors.white,
                size: 22.r,
              ),
              SizedBox(width: 10.w),
              Text(
                isDone ? 'أُنجز — انتقل للتالي' : 'اضغط للتسبيح',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Navigation Bar ───

class _NavigationBar extends StatelessWidget {
  final AdhkarReaderActive state;
  final _CategoryTheme theme;

  const _NavigationBar({required this.state, required this.theme});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          // Previous
          _NavButton(
            label: 'السابق',
            icon: Icons.arrow_forward_ios_rounded,
            isEnabled: !state.isFirst,
            theme: theme,
            onTap: () => context.read<AdhkarReaderCubit>().previous(),
          ),

          // Dots
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    math.min(state.adhkar.length, 12),
                    (i) {
                      final isCurrent = i == state.currentIndex;
                      final isDone = (state.counts[state.adhkar[i].id] ?? 0) >=
                          state.adhkar[i].repeatCount;
                      return GestureDetector(
                        onTap: () =>
                            context.read<AdhkarReaderCubit>().goTo(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: EdgeInsets.symmetric(horizontal: 3.w),
                          width: isCurrent ? 18.w : 7.w,
                          height: 7.h,
                          decoration: BoxDecoration(
                            color: isDone
                                ? AppColors.success
                                : isCurrent
                                    ? theme.primary
                                    : colors.divider,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // Next
          _NavButton(
            label: 'التالي',
            icon: Icons.arrow_back_ios_rounded,
            isEnabled: !state.isLast,
            theme: theme,
            onTap: () => context.read<AdhkarReaderCubit>().next(),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isEnabled;
  final _CategoryTheme theme;
  final VoidCallback onTap;

  const _NavButton({
    required this.label,
    required this.icon,
    required this.isEnabled,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = isEnabled ? theme.primary : colors.textSecondary.withValues(alpha: 0.4);

    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.r, color: color),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Complete Screen ───

class _CompleteBody extends StatelessWidget {
  final ZikrCategory category;
  final _CategoryTheme theme;
  final int total;

  const _CompleteBody({
    required this.category,
    required this.theme,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Success icon
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (_, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                width: 100.r,
                height: 100.r,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 56.r,
                  color: AppColors.success,
                ),
              ),
            ),
            SizedBox(height: 28.h),

            Text(
              'الحمد لله',
              style: TextStyle(
                fontSize: 28.sp,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            SizedBox(height: 10.h),

            Text(
              'أكملت ${category.label}',
              style: TextStyle(
                fontSize: 16.sp,
                color: theme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6.h),

            Text(
              '${toArabicNumerals(total.toString())} أذكار — تقبّل الله منك',
              style: TextStyle(
                fontSize: 14.sp,
                color: colors.textSecondary,
              ),
            ),
            SizedBox(height: 48.h),

            // Reset
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    context.read<AdhkarReaderCubit>().reset(),
                icon: Icon(Icons.replay_rounded, size: 20.r),
                label: Text(
                  'إعادة من البداية',
                  style: TextStyle(fontSize: 15.sp),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primary,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r)),
                ),
              ),
            ),
            SizedBox(height: 12.h),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textSecondary,
                  side: BorderSide(color: colors.divider),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r)),
                ),
                child: Text('العودة', style: TextStyle(fontSize: 15.sp)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error ───

class _ErrorBody extends StatelessWidget {
  final String message;
  const _ErrorBody({required this.message});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48.r, color: AppColors.error),
            SizedBox(height: 12.h),
            Text(message,
                style: TextStyle(
                    fontSize: 14.sp,
                    color: context.colors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
