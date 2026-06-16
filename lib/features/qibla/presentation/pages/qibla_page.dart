import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/qibla_cubit.dart';

class QiblaPage extends StatelessWidget {
  const QiblaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<QiblaCubit>()..load(),
      child: const _QiblaView(),
    );
  }
}

class _QiblaView extends StatelessWidget {
  const _QiblaView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: BlocBuilder<QiblaCubit, QiblaState>(
          builder: (context, state) {
            if (state is QiblaLoading || state is QiblaInitial) {
              return const _LoadingView();
            }
            if (state is QiblaPermissionDenied) {
              return _PermissionView(
                onRetry: () => context.read<QiblaCubit>().load(),
              );
            }
            if (state is QiblaNoLocation) {
              return const _NoLocationView();
            }
            if (state is QiblaError) {
              return _ErrorView(
                message: state.message,
                onRetry: () => context.read<QiblaCubit>().load(),
              );
            }
            if (state is QiblaLoaded) {
              return _LoadedView(state: state);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

// ─── Loading ───

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16.h),
          Text(
            'جارٍ تحديد موقعك...',
            style: TextStyle(
              fontSize: 15.sp,
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Permission Denied ───

class _PermissionView extends StatelessWidget {
  final VoidCallback onRetry;
  const _PermissionView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined,
                size: 56.r, color: colors.textSecondary),
            SizedBox(height: 16.h),
            Text(
              'إذن الموقع مطلوب',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'لتحديد اتجاه القبلة نحتاج إلى معرفة موقعك الجغرافي.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: colors.textSecondary,
                height: 1.6,
              ),
            ),
            SizedBox(height: 24.h),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding:
                    EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
              ),
              child: Text('السماح بالوصول', style: TextStyle(fontSize: 15.sp)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── No Location ───

class _NoLocationView extends StatelessWidget {
  const _NoLocationView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.my_location_outlined,
                size: 56.r, color: colors.textSecondary),
            SizedBox(height: 16.h),
            Text(
              'الموقع غير محدد',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'يرجى تحديد موقعك من الشاشة الرئيسية أولاً، ثم العودة هنا.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14.sp, color: colors.textSecondary, height: 1.6),
            ),
            SizedBox(height: 24.h),
            FilledButton(
              onPressed: () => context.read<QiblaCubit>().load(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding:
                    EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
              ),
              child: Text('إعادة المحاولة', style: TextStyle(fontSize: 15.sp)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error ───

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56.r, color: AppColors.error),
            SizedBox(height: 16.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: colors.textSecondary),
            ),
            SizedBox(height: 24.h),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Loaded ───

class _LoadedView extends StatelessWidget {
  final QiblaLoaded state;
  const _LoadedView({required this.state});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasCompass = state.compassHeading != null;
    final needDegrees = hasCompass
        ? (state.entity.qiblaDirection - state.compassHeading!) % 360
        : state.entity.qiblaDirection;
    final isAligned =
        hasCompass && (needDegrees < 5 || needDegrees > 355);
    final poorAccuracy =
        hasCompass && state.accuracy != null && state.accuracy! > 25;

    return Column(
      children: [
        SizedBox(height: 12.h),
        _InfoCard(state: state),
        if (poorAccuracy) ...[
          SizedBox(height: 8.h),
          _CalibrationBanner(),
        ],
        Expanded(
          child: Center(
            child: _CompassSection(
              qiblaDirection: state.entity.qiblaDirection,
              compassHeading: state.compassHeading,
              isAligned: isAligned,
              hasCompass: hasCompass,
            ),
          ),
        ),
        _DirectionLabel(
          needDegrees: needDegrees,
          isAligned: isAligned,
          hasCompass: hasCompass,
          colors: colors,
        ),
        SizedBox(height: 24.h),
      ],
    );
  }
}

// ─── Info Card ───

class _InfoCard extends StatelessWidget {
  final QiblaLoaded state;
  const _InfoCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final distance = state.entity.distanceKm;
    final distanceText = distance >= 1000
        ? '${(distance / 1000).toStringAsFixed(1)} ألف كم'
        : '${distance.round()} كم';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: colors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 40.r,
              height: 40.r,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mosque_outlined,
                size: 20.r,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مكة المكرمة',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'على بُعد $distanceText',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${state.entity.qiblaDirection.round()}°',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  'من الشمال',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Calibration Banner ───

class _CalibrationBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: const Color(0xFFFFE082)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFF9A825), size: 18),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'دقة البوصلة منخفضة — حرّك الجهاز بشكل رقم 8',
                style: TextStyle(
                    fontSize: 12.sp, color: const Color(0xFF795548)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Compass Section ───

class _CompassSection extends StatelessWidget {
  final double qiblaDirection;
  final double? compassHeading;
  final bool isAligned;
  final bool hasCompass;

  const _CompassSection({
    required this.qiblaDirection,
    required this.compassHeading,
    required this.isAligned,
    required this.hasCompass,
  });

  @override
  Widget build(BuildContext context) {
    final size = math.min(0.75.sw, 0.45.sh);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Compass ring
          CustomPaint(
            size: Size(size, size),
            painter: _CompassRingPainter(
              isDark: Theme.of(context).brightness == Brightness.dark,
            ),
          ),
          // Needle
          if (hasCompass)
            _AnimatedNeedle(
              qiblaDirection: qiblaDirection,
              compassHeading: compassHeading!,
              isAligned: isAligned,
              size: size,
            )
          else
            _StaticNeedle(
              qiblaDirection: qiblaDirection,
              size: size,
            ),
          // Center dot
          Container(
            width: 12.r,
            height: 12.r,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Animated Needle ───

class _AnimatedNeedle extends StatefulWidget {
  final double qiblaDirection;
  final double compassHeading;
  final bool isAligned;
  final double size;

  const _AnimatedNeedle({
    required this.qiblaDirection,
    required this.compassHeading,
    required this.isAligned,
    required this.size,
  });

  @override
  State<_AnimatedNeedle> createState() => _AnimatedNeedleState();
}

class _AnimatedNeedleState extends State<_AnimatedNeedle> {
  double _targetTurns = 0;
  bool _initialized = false;

  double _computeNeedleDeg(double qibla, double heading) {
    return (qibla - heading) % 360;
  }

  @override
  void didUpdateWidget(_AnimatedNeedle old) {
    super.didUpdateWidget(old);
    final newDeg = _computeNeedleDeg(
        widget.qiblaDirection, widget.compassHeading);
    if (!_initialized) {
      _targetTurns = newDeg / 360.0;
      _initialized = true;
      return;
    }
    final oldDeg =
        _computeNeedleDeg(old.qiblaDirection, old.compassHeading);
    double delta = newDeg - oldDeg;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    _targetTurns += delta / 360.0;
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      _targetTurns =
          _computeNeedleDeg(widget.qiblaDirection, widget.compassHeading) /
              360.0;
      _initialized = true;
    }
    return AnimatedRotation(
      turns: _targetTurns,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _NeedlePainter(isAligned: widget.isAligned),
      ),
    );
  }
}

// ─── Static Needle (no compass sensor) ───

class _StaticNeedle extends StatelessWidget {
  final double qiblaDirection;
  final double size;

  const _StaticNeedle({required this.qiblaDirection, required this.size});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: qiblaDirection * math.pi / 180,
      child: CustomPaint(
        size: Size(size, size),
        painter: const _NeedlePainter(isAligned: false),
      ),
    );
  }
}

// ─── Compass Ring Painter ───

class _CompassRingPainter extends CustomPainter {
  final bool isDark;
  const _CompassRingPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final innerRadius = radius * 0.82;

    final bgPaint = Paint()
      ..color = isDark ? AppColors.cardDark : AppColors.cardLight
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Outer border
    final borderPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius - 1.5, borderPaint);

    // Inner ring
    final innerBorderPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, innerRadius, innerBorderPaint);

    // Tick marks
    for (int i = 0; i < 72; i++) {
      final angle = i * 5 * math.pi / 180;
      final isMajor = i % 6 == 0; // every 30 degrees
      final isCardinal = i % 18 == 0; // every 90 degrees
      final tickLen =
          isCardinal ? radius * 0.14 : (isMajor ? radius * 0.08 : radius * 0.04);
      final tickStart = radius - 3;
      final tickEnd = tickStart - tickLen;

      final sin = math.sin(angle - math.pi / 2);
      final cos = math.cos(angle - math.pi / 2);

      canvas.drawLine(
        Offset(center.dx + tickStart * cos, center.dy + tickStart * sin),
        Offset(center.dx + tickEnd * cos, center.dy + tickEnd * sin),
        Paint()
          ..color = isCardinal
              ? AppColors.primary
              : (isMajor
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : (isDark
                      ? AppColors.textSecondaryDark.withValues(alpha: 0.3)
                      : AppColors.textSecondaryLight.withValues(alpha: 0.3)))
          ..strokeWidth = isCardinal ? 2.5 : (isMajor ? 1.5 : 1),
      );
    }

    // Cardinal labels
    final cardinals = ['ش', 'ق', 'ج', 'غ']; // N, E, S, W
    final labelRadius = radius * 0.67;
    for (int i = 0; i < 4; i++) {
      final angle = i * 90 * math.pi / 180;
      final sin = math.sin(angle - math.pi / 2);
      final cos = math.cos(angle - math.pi / 2);
      final isNorth = i == 0;

      final tp = TextPainter(
        text: TextSpan(
          text: cardinals[i],
          style: TextStyle(
            color: isNorth ? AppColors.primary : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
            fontSize: isNorth ? 16 : 13,
            fontWeight: isNorth ? FontWeight.w800 : FontWeight.w600,
            fontFamily: 'Cairo',
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout();

      tp.paint(
        canvas,
        Offset(
          center.dx + labelRadius * cos - tp.width / 2,
          center.dy + labelRadius * sin - tp.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_CompassRingPainter old) => old.isDark != isDark;
}

// ─── Needle Painter ───

class _NeedlePainter extends CustomPainter {
  final bool isAligned;
  const _NeedlePainter({required this.isAligned});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final R = size.width / 2;
    final color = isAligned ? AppColors.gold : AppColors.primary;

    // Kaaba dimensions (taller than wide, like the real Kaaba ~13m tall × 11m wide)
    final kaabaH = size.width * 0.22;
    final kaabaW = kaabaH * 0.86;
    final kaabaTopY = center.dy - R + 5;
    final kaabaBottomY = kaabaTopY + kaabaH;
    final kaabaCenter = Offset(center.dx, kaabaTopY + kaabaH / 2);

    // Needle triangle from kaaba bottom to center
    final needleWidth = R * 0.088;
    final topPath = Path()
      ..moveTo(center.dx, kaabaBottomY)
      ..lineTo(center.dx - needleWidth, center.dy)
      ..lineTo(center.dx + needleWidth, center.dy)
      ..close();
    canvas.drawPath(topPath, Paint()..color = color);

    // Needle highlight (left edge lighter)
    final highlightPath = Path()
      ..moveTo(center.dx, kaabaBottomY)
      ..lineTo(center.dx - needleWidth, center.dy)
      ..lineTo(center.dx, center.dy)
      ..close();
    canvas.drawPath(
      highlightPath,
      Paint()..color = Colors.white.withValues(alpha: 0.15),
    );

    // Counter-needle (bottom, shorter)
    final tailLen = R * 0.28;
    final tailPath = Path()
      ..moveTo(center.dx, center.dy + tailLen)
      ..lineTo(center.dx - needleWidth * 0.65, center.dy)
      ..lineTo(center.dx + needleWidth * 0.65, center.dy)
      ..close();
    canvas.drawPath(
      tailPath,
      Paint()..color = color.withValues(alpha: 0.38),
    );

    // Draw the Kaaba
    _drawKaaba(canvas, kaabaCenter, kaabaW, kaabaH);
  }

  void _drawKaaba(Canvas canvas, Offset center, double w, double h) {
    final left = center.dx - w / 2;
    final top = center.dy - h / 2;
    final right = left + w;
    final bottom = top + h;
    final body = Rect.fromLTRB(left, top, right, bottom);

    // Glow / shadow
    if (isAligned) {
      canvas.drawRect(
        body.inflate(4),
        Paint()
          ..color = AppColors.gold.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    } else {
      canvas.drawRect(
        body.inflate(2),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // ── Main body (Kiswa — very dark black-green) ──
    canvas.drawRect(body, Paint()..color = const Color(0xFF0C1409));

    // ── Top decorative embroidery band (Tirmah) ──
    canvas.drawRect(
      Rect.fromLTWH(left, top, w, h * 0.055),
      Paint()..color = AppColors.gold,
    );

    // ── Kiswa upper calligraphy zone (subtle lighter stripe) ──
    canvas.drawRect(
      Rect.fromLTWH(left, top + h * 0.055, w, h * 0.055),
      Paint()..color = AppColors.gold.withValues(alpha: 0.22),
    );

    // ── Hizam — golden belt (دائماً ذهبي) ──
    final beltTop = top + h * 0.36;
    final beltH = h * 0.135;
    // Belt shadow line above
    canvas.drawRect(
      Rect.fromLTWH(left, beltTop - h * 0.03, w, h * 0.025),
      Paint()..color = AppColors.gold.withValues(alpha: 0.55),
    );
    // Belt main
    canvas.drawRect(
      Rect.fromLTWH(left, beltTop, w, beltH),
      Paint()..color = AppColors.gold,
    );
    // Belt inner pattern (dark line through middle)
    canvas.drawRect(
      Rect.fromLTWH(left + w * 0.05, beltTop + beltH * 0.4, w * 0.9, beltH * 0.2),
      Paint()..color = const Color(0xFF0C1409).withValues(alpha: 0.5),
    );
    // Belt shadow line below
    canvas.drawRect(
      Rect.fromLTWH(left, beltTop + beltH, w, h * 0.025),
      Paint()..color = AppColors.gold.withValues(alpha: 0.45),
    );

    // ── Door (Bab al-Kaaba) — golden arch (دائماً ذهبي) ──
    final doorW = w * 0.42;
    final doorLeft = center.dx - doorW / 2;
    final doorTop = top + h * 0.60;
    final archR = doorW / 2;

    // Outer door (gold)
    final outerDoor = Path()
      ..moveTo(doorLeft, bottom)
      ..lineTo(doorLeft, doorTop + archR)
      ..arcToPoint(Offset(doorLeft + doorW, doorTop + archR),
          radius: Radius.circular(archR), clockwise: true)
      ..lineTo(doorLeft + doorW, bottom)
      ..close();
    canvas.drawPath(outerDoor, Paint()..color = AppColors.gold);

    // Inner door recess (dark, smaller arch inside outer door)
    final innerDoorW = doorW * 0.60;
    final innerDoorLeft = center.dx - innerDoorW / 2;
    final innerArchR = innerDoorW / 2;
    final innerDoorTop = doorTop + archR * 0.45;

    final innerDoor = Path()
      ..moveTo(innerDoorLeft, bottom)
      ..lineTo(innerDoorLeft, innerDoorTop + innerArchR)
      ..arcToPoint(Offset(innerDoorLeft + innerDoorW, innerDoorTop + innerArchR),
          radius: Radius.circular(innerArchR), clockwise: true)
      ..lineTo(innerDoorLeft + innerDoorW, bottom)
      ..close();
    canvas.drawPath(innerDoor, Paint()..color = const Color(0xFF060D04));

    // ── Gold border around Kaaba ──
    canvas.drawRect(
      body,
      Paint()
        ..color = AppColors.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // ── Corner accent lines (decorative) ──
    final cornerLen = h * 0.07;
    final cornerPaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.7)
      ..strokeWidth = 1.2;
    // top-left
    canvas.drawLine(Offset(left, top + cornerLen), Offset(left, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLen, top), cornerPaint);
    // top-right
    canvas.drawLine(Offset(right - cornerLen, top), Offset(right, top), cornerPaint);
    canvas.drawLine(Offset(right, top), Offset(right, top + cornerLen), cornerPaint);
    // bottom-left
    canvas.drawLine(Offset(left, bottom - cornerLen), Offset(left, bottom), cornerPaint);
    canvas.drawLine(Offset(left, bottom), Offset(left + cornerLen, bottom), cornerPaint);
    // bottom-right
    canvas.drawLine(Offset(right - cornerLen, bottom), Offset(right, bottom), cornerPaint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(_NeedlePainter old) => old.isAligned != isAligned;
}

// ─── Direction Label ───

class _DirectionLabel extends StatelessWidget {
  final double needDegrees;
  final bool isAligned;
  final bool hasCompass;
  final AppColorScheme colors;

  const _DirectionLabel({
    required this.needDegrees,
    required this.isAligned,
    required this.hasCompass,
    required this.colors,
  });

  String get _label {
    if (!hasCompass) return 'البوصلة غير متاحة في هذا الجهاز';
    if (isAligned) return '✦ أنت تواجه القبلة ✦';
    final deg = needDegrees.round();
    final right = deg <= 180;
    final turns = right ? deg : 360 - deg;
    return 'أدر $turns° نحو ${right ? 'اليمين' : 'اليسار'}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isAligned
              ? AppColors.gold.withValues(alpha: 0.15)
              : colors.surface,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isAligned ? AppColors.gold : colors.divider,
          ),
        ),
        child: Center(
          child: Text(
            _label,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: isAligned ? FontWeight.w700 : FontWeight.w500,
              color: isAligned ? AppColors.gold : colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
