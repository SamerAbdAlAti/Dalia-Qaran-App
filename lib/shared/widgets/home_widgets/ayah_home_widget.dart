import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class AyahHomeWidget extends StatelessWidget {
  final String ayahText;
  final String reference;

  const AyahHomeWidget({
    super.key,
    required this.ayahText,
    required this.reference,
  });

  @override
  Widget build(BuildContext context) {
    const bg = AppColors.primaryDark;
    const accent = AppColors.gold;
    const white = Colors.white;
    const dim = Color(0x99FFFFFF);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        width: 250,
        height: 110,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Header ───
              Row(children: [
                const Text('داليا',
                    style: TextStyle(
                        color: accent,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo')),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text('📖', style: TextStyle(fontSize: 9)),
                ),
              ]),
              const SizedBox(height: 8),
              // ─── Ayah text ───
              Text(
                ayahText,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: white,
                  fontSize: 12,
                  height: 1.6,
                  fontFamily: 'ScheherazadeNew',
                ),
              ),
              const SizedBox(height: 6),
              // ─── Reference ───
              Text(
                reference,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: dim, fontSize: 9, fontFamily: 'Cairo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
