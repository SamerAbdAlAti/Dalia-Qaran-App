import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../quran/presentation/cubit/mushaf_cubit.dart';
import '../../domain/entities/reciter_entity.dart';
import '../cubit/quran_audio_cubit.dart';
import 'download_choice_sheet.dart';

class ReciterPickerSheet extends StatefulWidget {
  const ReciterPickerSheet({super.key});

  @override
  State<ReciterPickerSheet> createState() => _ReciterPickerSheetState();
}

class _ReciterPickerSheetState extends State<ReciterPickerSheet> {
  final _fromPageCtrl = TextEditingController();
  final _toPageCtrl = TextEditingController();

  @override
  void dispose() {
    _fromPageCtrl.dispose();
    _toPageCtrl.dispose();
    super.dispose();
  }

  Future<bool> _hasDownloads(String identifier) async {
    final dir = await getApplicationDocumentsDirectory();
    final reciterDir = Directory('${dir.path}/quran_audio/$identifier');
    if (!await reciterDir.exists()) return false;
    final files = await reciterDir.list().length;
    return files > 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        border: Border(top: BorderSide(color: AppColors.gold, width: 1.5)),
      ),
      constraints: BoxConstraints(maxHeight: 0.85.sh),
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
          SizedBox(height: 12.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'اختر القارئ',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Icon(Icons.close,
                      size: 20.r, color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
          Divider(height: 16.h, color: context.colors.divider),
          Expanded(
            child: BlocBuilder<QuranAudioCubit, QuranAudioState>(
              builder: (context, state) {
                // Read reciters directly from the cubit — they're always available
                // regardless of whether audio is playing/paused/loading.
                final cubit = context.read<QuranAudioCubit>();
                final List reciters = cubit.reciters;
                String? selectedId;
                if (state is QuranAudioRecitersLoaded) {
                  selectedId = state.selectedReciter?.identifier;
                } else if (state is QuranAudioPlaying) {
                  selectedId = state.reciter.identifier;
                } else if (state is QuranAudioPaused) {
                  selectedId = state.reciter.identifier;
                } else {
                  selectedId = cubit.selectedReciter?.identifier;
                }

                if (reciters.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.r),
                      child: Text(
                        state is QuranAudioLoadingReciters
                            ? 'جاري تحميل قائمة القراء...'
                            : 'لا يوجد قراء متاحون، تحقق من الاتصال',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
                  itemCount: reciters.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: context.colors.divider),
                  itemBuilder: (context, i) {
                    final reciter = reciters[i];
                    final isSelected = reciter.identifier == selectedId;

                    return FutureBuilder<bool>(
                      future: _hasDownloads(reciter.identifier),
                      builder: (context, snapshot) {
                        final hasDownloads = snapshot.data ?? false;

                        return ListTile(
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 4.h),
                          onTap: () {
                            context
                                .read<QuranAudioCubit>()
                                .selectReciter(reciter);
                            Navigator.of(context).pop();
                          },
                          leading: isSelected
                              ? Icon(Icons.check_circle,
                                  color: AppColors.primary, size: 22.r)
                              : Icon(Icons.radio_button_unchecked,
                                  color: context.colors.textSecondary,
                                  size: 22.r),
                          title: Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              if (hasDownloads) ...[
                                Icon(
                                  Icons.download_done,
                                  size: 16.r,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 4.w),
                              ],
                              Expanded(
                                child: Text(
                                  reciter.arabicName,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppColors.primary
                                        : context.colors.textPrimary,
                                    fontSize: 15.sp,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            reciter.englishName,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 12.sp,
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.file_download_outlined,
                              size: 20.r,
                              color: context.colors.textSecondary,
                            ),
                            tooltip: 'تحميل',
                            onPressed: () =>
                                _showDownloadSheet(context, reciter),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          _PageRangeDownloadSection(
            fromCtrl: _fromPageCtrl,
            toCtrl: _toPageCtrl,
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + 8.h),
        ],
      ),
    );
  }

  void _showDownloadSheet(BuildContext context, dynamic reciter) {
    showDownloadChoiceSheet(
      context,
      reciter as ReciterEntity,
      onAfterStart: () => Navigator.of(context).pop(), // close reciter picker too
    );
  }
}

// ─── Page range download section ───

class _PageRangeDownloadSection extends StatelessWidget {
  final TextEditingController fromCtrl;
  final TextEditingController toCtrl;

  const _PageRangeDownloadSection({
    required this.fromCtrl,
    required this.toCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final inputDecoration = InputDecoration(
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.r),
        borderSide: BorderSide(color: AppColors.gold.withAlpha(100)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.r),
        borderSide: BorderSide(color: AppColors.gold.withAlpha(60)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.r),
        borderSide: BorderSide(color: AppColors.primary),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, color: context.colors.divider),
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Text(
                'تحميل نطاق الصفحات',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 56.w,
                child: TextField(
                  controller: fromCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: context.colors.textPrimary,
                  ),
                  decoration: inputDecoration.copyWith(hintText: 'من'),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 6.w),
                child: Text(
                  '—',
                  style: TextStyle(
                      color: context.colors.textSecondary, fontSize: 14.sp),
                ),
              ),
              SizedBox(
                width: 56.w,
                child: TextField(
                  controller: toCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: context.colors.textPrimary,
                  ),
                  decoration: inputDecoration.copyWith(hintText: 'إلى'),
                ),
              ),
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: () => _onDownload(context),
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(Icons.download, color: Colors.white, size: 18.r),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onDownload(BuildContext context) {
    final from = int.tryParse(fromCtrl.text.trim());
    final to = int.tryParse(toCtrl.text.trim());
    if (from == null || to == null || from > to || from < 1 || to > 604) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'أدخل نطاق صفحات صحيح (١ – ٦٠٤)',
            textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 13.sp),
          ),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }

    final mushafState = context.read<MushafCubit>().state;
    final surahFirstPages =
        mushafState is MushafReady ? mushafState.surahFirstPages : <int, int>{};

    context
        .read<QuranAudioCubit>()
        .downloadPageRange(from, to, surahFirstPages);
    Navigator.of(context).pop();
  }
}
