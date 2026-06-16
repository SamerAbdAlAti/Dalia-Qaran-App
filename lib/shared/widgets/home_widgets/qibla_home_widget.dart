import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class QiblaHomeWidget extends StatelessWidget {
  final double angle;
  final String cityName;

  const QiblaHomeWidget({
    super.key,
    required this.angle,
    required this.cityName,
  });

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0D2B14);
    const accent = AppColors.gold;
    const white = Colors.white;
    const dim = Color(0x88FFFFFF);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        width: 110,
        height: 110,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: bg,
            padding: const EdgeInsets.all(9),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header
                const Text('داليا',
                    style: TextStyle(
                        color: accent,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                        height: 1.0)),
                // Compass arrow
                Transform.rotate(
                  angle: angle * math.pi / 180,
                  child: const Icon(Icons.navigation_rounded,
                      color: accent, size: 24),
                ),
                // Degrees
                Text('${angle.round()}°',
                    style: const TextStyle(
                        color: white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                        height: 1.0)),
                // City name
                Text(cityName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: dim,
                        fontSize: 7,
                        fontFamily: 'Cairo',
                        height: 1.0)),
                // Subtitle
                const Text('اتجاه القبلة',
                    style: TextStyle(
                        color: AppColors.goldLight,
                        fontSize: 6,
                        fontFamily: 'Cairo',
                        height: 1.0)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
