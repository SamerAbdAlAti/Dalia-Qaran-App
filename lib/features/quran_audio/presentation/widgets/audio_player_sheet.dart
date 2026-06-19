import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/quran_audio_cubit.dart';
import 'reciter_picker_sheet.dart';

class AudioPlayerSheet extends StatelessWidget {
  final List<String> surahNames;
  final VoidCallback? onGoToCurrentPage;

  const AudioPlayerSheet({
    required this.surahNames,
    this.onGoToCurrentPage,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QuranAudioCubit, QuranAudioState>(
      builder: (context, state) {
        if (state is QuranAudioInitial ||
            state is QuranAudioLoadingReciters ||
            state is QuranAudioRecitersLoaded) {
          return const SizedBox.shrink();
        }

        return _PlayerSheetContent(
          state: state,
          surahNames: surahNames,
          onGoToCurrentPage: onGoToCurrentPage,
        );
      },
    );
  }
}

class _PlayerSheetContent extends StatelessWidget {
  final QuranAudioState state;
  final List<String> surahNames;
  final VoidCallback? onGoToCurrentPage;

  const _PlayerSheetContent({
    required this.state,
    required this.surahNames,
    this.onGoToCurrentPage,
  });

  String _surahName(int surahNum) {
    if (surahNum >= 1 && surahNum <= surahNames.length) {
      return surahNames[surahNum - 1];
    }
    return 'سورة $surahNum';
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String reciterName = '';
    int surahNum = 1;
    int? ayahNum;
    bool isSurah = false;
    bool isPlaying = false;
    bool isBuffering = false;
    bool isDownloading = false;
    double downloadProgress = 0;
    Duration position = Duration.zero;
    Duration? duration;

    if (state is QuranAudioPlaying) {
      final s = state as QuranAudioPlaying;
      reciterName = s.reciter.arabicName;
      surahNum = s.surahNum;
      ayahNum = s.ayahNum;
      isSurah = s.isSurah;
      isPlaying = true;
      isBuffering = s.isBuffering;
      position = s.position;
      duration = s.duration;
    } else if (state is QuranAudioPaused) {
      final s = state as QuranAudioPaused;
      reciterName = s.reciter.arabicName;
      surahNum = s.surahNum;
      ayahNum = s.ayahNum;
      isSurah = s.isSurah;
      isPlaying = false;
    } else if (state is QuranAudioDownloading) {
      final s = state as QuranAudioDownloading;
      reciterName = s.reciter.arabicName;
      surahNum = s.surahNum;
      isSurah = true;
      isDownloading = true;
      downloadProgress = s.progress;
    } else if (state is QuranAudioError) {
      return _ErrorBanner(message: (state as QuranAudioError).message);
    }

    final totalSecs = duration?.inSeconds ?? 0;
    final currentSecs = position.inSeconds.clamp(0, totalSecs > 0 ? totalSecs : 1);
    final bgColor = isDark ? const Color(0xFF1A2E19) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFEBD9A6) : AppColors.textPrimaryLight;
    final textSecondary = isDark ? Colors.white54 : Colors.black45;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(top: BorderSide(color: AppColors.gold, width: 1.5)),
      ),
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 16.w, 12.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Row 1: Close · Speed · [Go to page] · Reciter ─────────────
          Row(
            children: [
              // Close / stop
              GestureDetector(
                onTap: () => context.read<QuranAudioCubit>().stop(),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
                  child: Icon(Icons.close, size: 20.r, color: textSecondary),
                ),
              ),
              SizedBox(width: 4.w),
              // Speed badge — cycles through preset speeds
              ValueListenableBuilder<double>(
                valueListenable:
                    context.read<QuranAudioCubit>().playbackSpeedNotifier,
                builder: (_, speed, _) => GestureDetector(
                  onTap: () =>
                      context.read<QuranAudioCubit>().cyclePlaybackSpeed(),
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: speed != 1.0
                          ? AppColors.primary.withAlpha(25)
                          : (isDark
                              ? Colors.white.withAlpha(15)
                              : Colors.black.withAlpha(10)),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(
                        color: speed != 1.0
                            ? AppColors.primary.withAlpha(80)
                            : (isDark
                                ? Colors.white.withAlpha(30)
                                : Colors.black.withAlpha(20)),
                      ),
                    ),
                    child: Text(
                      _speedLabel(speed),
                      style: TextStyle(
                        color: speed != 1.0 ? AppColors.primary : textSecondary,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ),
              ),
              // "Go to current page" button — only when playing
              if (onGoToCurrentPage != null && !isDownloading) ...[
                SizedBox(width: 6.w),
                GestureDetector(
                  onTap: onGoToCurrentPage,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withAlpha(15)
                          : Colors.black.withAlpha(10),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withAlpha(30)
                            : Colors.black.withAlpha(20),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.my_location_rounded,
                            size: 11.r, color: textSecondary),
                        SizedBox(width: 3.w),
                        Text(
                          'الصفحة',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 10.sp,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // Reciter name — tappable to change
              GestureDetector(
                onTap: () => _showReciterPicker(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18.r, color: AppColors.primary),
                    SizedBox(width: 2.w),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 130.w),
                      child: Text(
                        reciterName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),
          // ── Row 2: Surah / Ayah info ──────────────────────────────────
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              isSurah
                  ? _surahName(surahNum)
                  : '${_surahName(surahNum)}  •  آية $ayahNum',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                fontSize: 12.sp,
              ),
            ),
          ),
          SizedBox(height: 6.h),
          // ── Row 3: Progress slider (surah mode only) ──────────────────
          if (!isDownloading && isSurah) ...[
            Row(
              children: [
                Text(
                  _formatDuration(duration ?? Duration.zero),
                  style: TextStyle(color: textSecondary, fontSize: 10.sp),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 2.h,
                      thumbShape:
                          RoundSliderThumbShape(enabledThumbRadius: 6.r),
                      overlayShape:
                          RoundSliderOverlayShape(overlayRadius: 12.r),
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: AppColors.primary.withAlpha(40),
                      thumbColor: AppColors.primary,
                      overlayColor: AppColors.primary.withAlpha(30),
                    ),
                    child: Slider(
                      value: totalSecs > 0 ? currentSecs.toDouble() : 0.0,
                      min: 0,
                      max: totalSecs > 0 ? totalSecs.toDouble() : 1.0,
                      onChanged: totalSecs > 0
                          ? (v) => context
                              .read<QuranAudioCubit>()
                              .seek(Duration(seconds: v.toInt()))
                          : null,
                    ),
                  ),
                ),
                Text(
                  _formatDuration(position),
                  style: TextStyle(color: textSecondary, fontSize: 10.sp),
                ),
              ],
            ),
          ],
          // ── Row 4: Controls ───────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Repeat
              ValueListenableBuilder<AudioRepeatMode>(
                valueListenable:
                    context.read<QuranAudioCubit>().repeatModeNotifier,
                builder: (_, mode, _) => _ControlBtn(
                  icon: mode == AudioRepeatMode.repeatOne
                      ? Icons.repeat_one
                      : Icons.repeat,
                  onTap: () => context.read<QuranAudioCubit>().setAudioRepeatMode(
                      mode == AudioRepeatMode.none
                          ? AudioRepeatMode.repeatOne
                          : AudioRepeatMode.none),
                  color: mode == AudioRepeatMode.repeatOne
                      ? AppColors.primary
                      : textSecondary,
                  isDark: isDark,
                ),
              ),
              // Skip previous
              _ControlBtn(
                icon: Icons.skip_previous_rounded,
                onTap: isDownloading
                    ? null
                    : () => context.read<QuranAudioCubit>().playPrev(),
                color: textPrimary,
                isDark: isDark,
              ),
              if (isSurah) ...[
                // Seek back 10s
                _ControlBtn(
                  icon: Icons.replay_10,
                  onTap: () {
                    final s = state;
                    if (s is QuranAudioPlaying) {
                      final newPos =
                          s.position - const Duration(seconds: 10);
                      context.read<QuranAudioCubit>().seek(
                          newPos < Duration.zero ? Duration.zero : newPos);
                    }
                  },
                  color: textPrimary,
                  isDark: isDark,
                ),
              ],
              // Play / Pause / Loading
              if (isBuffering || isDownloading)
                SizedBox(
                  width: 44.r,
                  height: 44.r,
                  child: const CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                )
              else
                GestureDetector(
                  onTap: () {
                    final cubit = context.read<QuranAudioCubit>();
                    isPlaying ? cubit.pause() : cubit.resume();
                  },
                  child: Container(
                    width: 44.r,
                    height: 44.r,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 24.r,
                    ),
                  ),
                ),
              if (isSurah) ...[
                // Seek forward 10s
                _ControlBtn(
                  icon: Icons.forward_10,
                  onTap: () {
                    final s = state;
                    if (s is QuranAudioPlaying && s.duration != null) {
                      final newPos =
                          s.position + const Duration(seconds: 10);
                      final max = s.duration!;
                      context
                          .read<QuranAudioCubit>()
                          .seek(newPos > max ? max : newPos);
                    }
                  },
                  color: textPrimary,
                  isDark: isDark,
                ),
              ],
              // Skip next
              _ControlBtn(
                icon: Icons.skip_next_rounded,
                onTap: isDownloading
                    ? null
                    : () => context.read<QuranAudioCubit>().playNext(),
                color: textPrimary,
                isDark: isDark,
              ),
              // Download (surah mode only)
              if (isSurah)
                _ControlBtn(
                  icon: Icons.download_outlined,
                  onTap: isDownloading
                      ? null
                      : () => context
                          .read<QuranAudioCubit>()
                          .downloadSurah(surahNum),
                  color: textPrimary,
                  isDark: isDark,
                ),
            ],
          ),
          // ── Row 5: Download progress bar ──────────────────────────────
          if (isDownloading) ...[
            SizedBox(height: 6.h),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2.r),
                    child: LinearProgressIndicator(
                      value: downloadProgress,
                      backgroundColor: AppColors.primary.withAlpha(30),
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.primary),
                      minHeight: 4,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  '${(downloadProgress * 100).toStringAsFixed(0)}٪',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _speedLabel(double speed) {
    if (speed == 1.0) return '1×';
    if (speed == speed.truncateToDouble()) return '${speed.toInt()}×';
    return '$speed×';
  }

  void _showReciterPicker(BuildContext context) {
    final cubit = context.read<QuranAudioCubit>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const ReciterPickerSheet(),
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final bool isDark;

  const _ControlBtn({
    required this.icon,
    required this.onTap,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(8.r),
        child: Icon(
          icon,
          color: onTap == null ? color.withAlpha(60) : color,
          size: 22.r,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.error.withAlpha(20),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 20.r),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: AppColors.error, fontSize: 13.sp),
            ),
          ),
          GestureDetector(
            onTap: () => context.read<QuranAudioCubit>().stop(),
            child: Icon(Icons.close, size: 18.r, color: AppColors.error),
          ),
        ],
      ),
    );
  }
}
