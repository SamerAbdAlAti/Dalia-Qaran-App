import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../app/app_shell.dart';
import '../../../../core/theme/app_colors.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  // ─── Icon ───
  late Animation<double> _iconScale;
  late Animation<double> _iconOpacity;
  late Animation<double> _iconGlow;

  // ─── Title ───
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;

  // ─── Subtitle ───
  late Animation<double> _subtitleOpacity;

  // ─── Divider ───
  late Animation<double> _dividerWidth;

  // ─── Background ornament ───
  late Animation<double> _ornamentOpacity;
  late Animation<double> _ornamentRotate;

  // ─── Stars ───
  late Animation<double> _starsOpacity;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    _ornamentOpacity = Tween<double>(begin: 0, end: 0.12).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.5)),
    );
    _ornamentRotate = Tween<double>(begin: 0, end: math.pi / 24).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 1.0, curve: Curves.easeInOut)),
    );

    _iconScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.1, 0.55, curve: Curves.elasticOut)),
    );
    _iconOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.1, 0.42)),
    );
    _iconGlow = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 0.7, curve: Curves.easeOut)),
    );

    _dividerWidth = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.48, 0.68, curve: Curves.easeOut)),
    );

    _titleOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.52, 0.72)),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.52, 0.72, curve: Curves.easeOut)),
    );

    _subtitleOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.68, 0.88)),
    );

    _starsOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.75, 0.95)),
    );

    _ctrl.forward();

    // Remove native splash after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

    // Navigate to AppShell after animation
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 600),
              pageBuilder: (_, _, _) => const AppShell(),
              transitionsBuilder: (_, animation, _, child) => FadeTransition(
                opacity: animation,
                child: child,
              ),
            ),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => Stack(
          children: [
            // ── Background gradient ──
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.2, -0.3),
                  radius: 1.2,
                  colors: [Color(0xFF2D5A27), Color(0xFF1A3A18), Color(0xFF0D2210)],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // ── Rotating Islamic geometric ornament ──
            Positioned.fill(
              child: Opacity(
                opacity: _ornamentOpacity.value,
                child: Transform.rotate(
                  angle: _ornamentRotate.value,
                  child: CustomPaint(painter: _GeometricPainter()),
                ),
              ),
            ),

            // ── Main content ──
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // ── App Icon with glow ──
                  Transform.scale(
                    scale: _iconScale.value,
                    child: Opacity(
                      opacity: _iconOpacity.value,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Glow ring
                          Container(
                            width: 200.r,
                            height: 200.r,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.6 * _iconGlow.value,
                                  ),
                                  blurRadius: 60,
                                  spreadRadius: 20,
                                ),
                                BoxShadow(
                                  color: AppColors.gold.withValues(
                                    alpha: 0.3 * _iconGlow.value,
                                  ),
                                  blurRadius: 100,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          // Icon container
                          Container(
                            width: 160.r,
                            height: 160.r,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(36.r),
                              border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.5),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              'design/icon_1024.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _FallbackIcon(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 32.h),

                  // ── Gold divider ──
                  SizedBox(
                    width: 200.w * _dividerWidth.value,
                    child: const Divider(color: AppColors.gold, thickness: 1),
                  ),

                  SizedBox(height: 24.h),

                  // ── App name ──
                  SlideTransition(
                    position: _titleSlide,
                    child: FadeTransition(
                      opacity: _titleOpacity,
                      child: Text(
                        'داليا',
                        style: TextStyle(
                          fontSize: 64.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.gold,
                          letterSpacing: 4,
                          shadows: [
                            Shadow(
                              color: AppColors.gold.withValues(alpha: 0.5),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 10.h),

                  // ── Subtitle ──
                  FadeTransition(
                    opacity: _subtitleOpacity,
                    child: Text(
                      'القرآن الكريم  ·  أوقات الصلاة  ·  القبلة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: Colors.white.withValues(alpha: 0.65),
                        letterSpacing: 1.5,
                        height: 1.6,
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // ── Crescent + stars ──
                  FadeTransition(
                    opacity: _starsOpacity,
                    child: _CrescentDecoration(),
                  ),

                  const Spacer(flex: 1),

                  // ── Bottom tagline ──
                  FadeTransition(
                    opacity: _subtitleOpacity,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 24.h),
                      child: Text(
                        'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.gold.withValues(alpha: 0.6),
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Fallback when asset not ready ───
class _FallbackIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryDark,
      child: Center(
        child: Text(
          '📖',
          style: TextStyle(fontSize: 80.sp),
        ),
      ),
    );
  }
}

// ─── Crescent + 3 stars decoration ───
class _CrescentDecoration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Star(size: 8.r),
        SizedBox(width: 16.w),
        CustomPaint(
          size: Size(44.r, 44.r),
          painter: _CrescentPainter(),
        ),
        SizedBox(width: 16.w),
        _Star(size: 14.r),
        SizedBox(width: 10.w),
        _Star(size: 8.r),
      ],
    );
  }
}

class _Star extends StatelessWidget {
  final double size;
  const _Star({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _StarPainter(),
    );
  }
}

// ─── Custom Painters ───

class _GeometricPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD4A847)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final cx = size.width / 2;
    final cy = size.height / 2;

    for (final r in [size.width * 0.35, size.width * 0.48, size.width * 0.61]) {
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }

    // 8-pointed star
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final outerAngle = (i * math.pi / 4) - math.pi / 2;
      final innerAngle = outerAngle + math.pi / 8;
      final outer = Offset(
        cx + size.width * 0.44 * math.cos(outerAngle),
        cy + size.width * 0.44 * math.sin(outerAngle),
      );
      final inner = Offset(
        cx + size.width * 0.2 * math.cos(innerAngle),
        cy + size.width * 0.2 * math.sin(innerAngle),
      );
      if (i == 0) {
        path.moveTo(outer.dx, outer.dy);
      } else {
        path.lineTo(outer.dx, outer.dy);
      }
      path.lineTo(inner.dx, inner.dy);
    }
    path.close();
    canvas.drawPath(path, paint..strokeWidth = 1);

    // Cross lines
    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 4;
      canvas.drawLine(
        Offset(cx + size.width * 0.61 * math.cos(angle), cy + size.width * 0.61 * math.sin(angle)),
        Offset(cx - size.width * 0.61 * math.cos(angle), cy - size.width * 0.61 * math.sin(angle)),
        paint..strokeWidth = 0.8,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _CrescentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Outer circle
    canvas.drawCircle(Offset(cx, cy), r, paint);
    // Cut inner circle to make crescent
    canvas.drawCircle(
      Offset(cx + r * 0.35, cy - r * 0.1),
      r * 0.82,
      paint..color = AppColors.primaryDark,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outer = Offset(
        cx + size.width / 2 * math.cos((i * 4 * math.pi / 5) - math.pi / 2),
        cy + size.height / 2 * math.sin((i * 4 * math.pi / 5) - math.pi / 2),
      );
      if (i == 0) {
        path.moveTo(outer.dx, outer.dy);
      } else {
        path.lineTo(outer.dx, outer.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
