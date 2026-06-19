import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/reciter_entity.dart';
import '../cubit/quran_audio_cubit.dart';

/// ورقة اختيار نوع التحميل لقارئ — القرآن كامل أو سورة محددة، وسور كاملة
/// ("غير مقطعة") أو آيات منفصلة ("مقطعة"). تُستخدم من صفحة القرآن (اختيار
/// القارئ) ومن الإعدادات.
void showDownloadChoiceSheet(
  BuildContext context,
  ReciterEntity reciter, {
  VoidCallback? onAfterStart,
}) {
  final audioCubit = context.read<QuranAudioCubit>();
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => BlocProvider.value(
      value: audioCubit,
      child: DownloadChoiceSheet(reciter: reciter, onAfterStart: onAfterStart),
    ),
  );
}

class DownloadChoiceSheet extends StatefulWidget {
  final ReciterEntity reciter;
  final VoidCallback? onAfterStart;

  const DownloadChoiceSheet({
    required this.reciter,
    this.onAfterStart,
    super.key,
  });

  @override
  State<DownloadChoiceSheet> createState() => _DownloadChoiceSheetState();
}

class _DownloadChoiceSheetState extends State<DownloadChoiceSheet> {
  bool _segmented = false;
  int? _singleSurah; // null = القرآن كامل

  Future<void> _pickSurah() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _SurahPickerSheet(),
    );
    if (picked != null) setState(() => _singleSurah = picked);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scopeLabel = _singleSurah == null
        ? 'القرآن كامل'
        : 'سورة ${QuranAudioCubit.surahNameFor(_singleSurah!)}';

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        border: Border(top: BorderSide(color: AppColors.gold, width: 1.5)),
      ),
      padding: EdgeInsets.fromLTRB(
        20.w,
        16.h,
        20.w,
        MediaQuery.paddingOf(context).bottom + 24.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(80),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          SizedBox(height: 20.h),
          Icon(
            Icons.download_for_offline_outlined,
            color: AppColors.primary,
            size: 40.r,
          ),
          SizedBox(height: 12.h),
          Text(
            widget.reciter.arabicName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'اختر نطاق ونوع التحميل للاستماع بدون إنترنت',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13.sp,
              height: 1.5,
            ),
          ),
          SizedBox(height: 18.h),

          // ── نطاق التحميل: القرآن كامل / سورة محددة ──
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: Text(
                  'نطاق التحميل',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _pickSurah,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: AppColors.primary.withAlpha(100)),
                  ),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        scopeLabel,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16.r,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
              if (_singleSurah != null) ...[
                SizedBox(width: 6.w),
                GestureDetector(
                  onTap: () => setState(() => _singleSurah = null),
                  child: Icon(
                    Icons.close,
                    size: 16.r,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 18.h),

          // ── نوع الملفات: سور كاملة / آيات منفصلة ──
          Row(
            children: [
              Expanded(
                child: _TypeOption(
                  icon: Icons.menu_book_rounded,
                  label: 'سور كاملة',
                  subtitle: 'غير مقطّعة',
                  selected: !_segmented,
                  onTap: () => setState(() => _segmented = false),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _TypeOption(
                  icon: Icons.format_list_numbered_rounded,
                  label: 'آيات منفصلة',
                  subtitle: 'مقطّعة — أكبر وأبطأ',
                  selected: _segmented,
                  onTap: () => setState(() => _segmented = true),
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final cubit = context.read<QuranAudioCubit>();
                final singleSurah = _singleSurah;
                final segmented = _segmented;
                Navigator.of(context).pop();
                widget.onAfterStart?.call();
                if (singleSurah != null) {
                  cubit.downloadSurahForReciter(
                    widget.reciter,
                    singleSurah,
                    segmented: segmented,
                  );
                } else if (segmented) {
                  cubit.downloadAllAyahsForReciter(widget.reciter);
                } else {
                  cubit.downloadAllForReciter(widget.reciter);
                }
              },
              icon: Icon(Icons.download, size: 18.r),
              label: Text(
                _segmented ? 'تحميل الآيات منفصلة' : 'تحميل السور كاملة',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
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
        ],
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _TypeOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 8.w),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withAlpha(18) : colors.surface,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.black12,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? AppColors.primary : colors.textSecondary,
              size: 22.r,
            ),
            SizedBox(height: 6.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.primary : colors.textPrimary,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.sp, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Surah picker (returns the chosen 1-based surah number) ───

class _SurahPickerSheet extends StatefulWidget {
  const _SurahPickerSheet();

  @override
  State<_SurahPickerSheet> createState() => _SurahPickerSheetState();
}

class _SurahPickerSheetState extends State<_SurahPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final items = List.generate(QuranAudioCubit.surahNames.length, (i) => i + 1)
        .where(
          (n) =>
              _query.isEmpty ||
              QuranAudioCubit.surahNameFor(n).contains(_query),
        )
        .toList();

    // ListTile paints ink splashes on the nearest Material ancestor — a
    // plain Container with a background color hides them (see CityPickerSheet).
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      child: Container(
        constraints: BoxConstraints(maxHeight: 0.75.sh),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.gold, width: 1.5)),
        ),
        child: Material(
          color: colors.card,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 12.h),
              Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(80),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                child: TextField(
                  controller: _searchCtrl,
                  textAlign: TextAlign.right,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن سورة',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: colors.divider),
                  itemBuilder: (_, i) {
                    final num = items[i];
                    return ListTile(
                      dense: true,
                      title: Text(
                        QuranAudioCubit.surahNameFor(num),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14.sp,
                        ),
                      ),
                      trailing: Text(
                        '$num',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12.sp,
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop(num),
                    );
                  },
                ),
              ),
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 8.h),
            ],
          ),
        ),
      ),
    );
  }
}
