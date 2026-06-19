import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/tafsir_cubit.dart';

String _toArabicNumTafsir(int n) {
  const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return n.toString().split('').map((c) => d[int.parse(c)]).join();
}

void showTafsirSheet(
  BuildContext context, {
  required int surahId,
  required int ayahNum,
  required String surahName,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (_) => BlocProvider(
      create: (_) => sl<TafsirCubit>()..load(surahId, ayahNum),
      child: TafsirSheet(
        surahId: surahId,
        ayahNum: ayahNum,
        surahName: surahName,
      ),
    ),
  );
}

class TafsirSheet extends StatelessWidget {
  final int surahId;
  final int ayahNum;
  final String surahName;

  const TafsirSheet({
    required this.surahId,
    required this.ayahNum,
    required this.surahName,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A12) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFEBD9A6) : const Color(0xFF1A0A00);
    final textSec = isDark ? Colors.white54 : Colors.black45;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          border: Border(top: BorderSide(color: AppColors.gold, width: 1.5)),
        ),
        child: Column(
          children: [
            SizedBox(height: 14.h),
            Container(
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(80),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              '﴾ تفسير سورة $surahName — آية ${_toArabicNumTafsir(ayahNum)} ﴿',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'ScheherazadeNew',
                fontSize: 17.sp,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12.h),
            Divider(height: 0.5, color: isDark ? Colors.white12 : Colors.black12),
            Expanded(
              child: BlocBuilder<TafsirCubit, TafsirState>(
                builder: (context, state) {
                  if (state is TafsirLoading || state is TafsirInitial) {
                    return Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }
                  if (state is TafsirError) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.r),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, color: AppColors.error, size: 28.r),
                            SizedBox(height: 10.h),
                            Text(
                              state.message,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textSec, fontSize: 13.sp, fontFamily: 'Cairo'),
                            ),
                            SizedBox(height: 14.h),
                            ElevatedButton(
                              onPressed: () =>
                                  context.read<TafsirCubit>().load(surahId, ayahNum),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.r)),
                              ),
                              child: Text('إعادة المحاولة',
                                  style: TextStyle(fontSize: 13.sp, fontFamily: 'Cairo')),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final text = state is TafsirLoaded ? state.text : '';
                  return SingleChildScrollView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
                    child: Text(
                      text,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 15.sp,
                        fontFamily: 'Cairo',
                        height: 1.9,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
