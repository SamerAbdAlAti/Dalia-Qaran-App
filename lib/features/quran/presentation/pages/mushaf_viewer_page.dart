import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qcf_quran/qcf_quran.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/mushaf_entities.dart';
import '../cubit/mushaf_cubit.dart';
import '../../../quran_audio/presentation/cubit/quran_audio_cubit.dart';
import '../../../quran_audio/presentation/widgets/audio_player_sheet.dart';

// ─── Constants ───

const _totalPages = 604;

String _toArabicNum(int n) {
  const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return n.toString().split('').map((c) => d[int.parse(c)]).join();
}

final _highlightColors = [
  null,
  const Color(0xFFFFF176), // yellow
  const Color(0xFFA5D6A7), // green
  const Color(0xFF90CAF9), // blue
  const Color(0xFFF48FB1), // pink
];

// ─── Entry Page ───

class MushafViewerPage extends StatefulWidget {
  final int? surahId;
  final int? initialPage;

  const MushafViewerPage({this.surahId, this.initialPage, super.key});

  @override
  State<MushafViewerPage> createState() => _MushafViewerPageState();
}

class _MushafViewerPageState extends State<MushafViewerPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<MushafCubit>()
            ..initialize(startPage: widget.initialPage),
        ),
        BlocProvider(
          create: (_) => sl<QuranAudioCubit>()..loadReciters(),
        ),
      ],
      child: _MushafContent(surahId: widget.surahId),
    );
  }
}

// ─── Content ───

class _MushafContent extends StatefulWidget {
  final int? surahId;
  const _MushafContent({this.surahId});

  @override
  State<_MushafContent> createState() => _MushafContentState();
}

class _MushafContentState extends State<_MushafContent> {
  PageController? _pageController;
  bool _showControls = false;
  bool _showPanel = true;
  Timer? _hideControlsTimer;
  final _selectedAyah = ValueNotifier<(int, int)?>(null);

  void _goToPage(int page) {
    _pageController?.jumpToPage(page - 1);
  }

  void _showControlsTemporarily() {
    if (!mounted) return;
    _hideControlsTimer?.cancel();
    setState(() => _showControls = true);
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  // When audio advances to a new ayah on the next page, auto-flip there.
  void _checkAndAdvancePage(BuildContext context, int surahNum, int ayahNum) {
    final mushafCubit = context.read<MushafCubit>();
    final ms = mushafCubit.state;
    if (ms is! MushafReady) return;

    final currentPage = ms.currentPage;
    final currentData = mushafCubit.getPageData(currentPage);
    final onCurrentPage = currentData?.ayahs.any(
          (a) => a.surahId == surahNum && a.ayahNum == ayahNum,
        ) ??
        false;
    if (!onCurrentPage && currentPage < _totalPages) {
      final nextData = mushafCubit.getPageData(currentPage + 1);
      final onNextPage = nextData?.ayahs.any(
            (a) => a.surahId == surahNum && a.ayahNum == ayahNum,
          ) ??
          false;
      if (onNextPage) {
        _pageController?.animateToPage(
          currentPage, // index = page - 1, next page index = currentPage
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<QuranAudioCubit, QuranAudioState>(
      listener: (context, audioState) {
        if (audioState is QuranAudioPlaying) {
          if (_showPanel) setState(() => _showPanel = false);
          if (!audioState.isSurah && audioState.ayahNum != null) {
            _checkAndAdvancePage(context, audioState.surahNum, audioState.ayahNum!);
          }
        } else if (audioState is QuranAudioInitial ||
            audioState is QuranAudioRecitersLoaded ||
            audioState is QuranAudioError) {
          if (!_showPanel) setState(() => _showPanel = true);
        }
      },
      child: BlocConsumer<MushafCubit, MushafState>(
        listenWhen: (prev, curr) =>
            prev is MushafLoading && curr is MushafReady,
        listener: (context, state) {
          if (state is MushafReady) {
            int startPage = state.currentPage;
            if (widget.surahId != null) {
              startPage = state.surahFirstPages[widget.surahId!] ?? startPage;
              context.read<MushafCubit>().setPage(startPage);
            }
            setState(() {
              _pageController = PageController(initialPage: startPage - 1);
            });
          }
        },
        builder: (context, state) {
          if (state is MushafLoading || state is MushafInitial) {
            return _LoadingView();
          }
          if (state is MushafError) {
            return _ErrorView(message: state.message);
          }
          if (state is MushafReady && _pageController != null) {
            return _ReaderView(
              state: state,
              controller: _pageController!,
              showControls: _showControls,
              showPanel: _showPanel,
              onTap: _showControlsTemporarily,
              onShowPanel: () {
                setState(() => _showPanel = true);
                _showControlsTemporarily();
              },
              onGoToPage: _goToPage,
              selectedAyah: _selectedAyah,
            );
          }
          return _LoadingView();
        },
      ),
    );
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _pageController?.dispose();
    _selectedAyah.dispose();
    super.dispose();
  }
}

// ─── Reader View ───

class _ReaderView extends StatelessWidget {
  final MushafReady state;
  final PageController controller;
  final bool showControls;
  final bool showPanel;
  final VoidCallback onTap;
  final VoidCallback onShowPanel;
  final void Function(int page) onGoToPage;
  final ValueNotifier<(int, int)?> selectedAyah;

  const _ReaderView({
    required this.state,
    required this.controller,
    required this.showControls,
    required this.showPanel,
    required this.onTap,
    required this.onShowPanel,
    required this.onGoToPage,
    required this.selectedAyah,
  });


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final surahNames = state.surahInfos
        .map((s) => s.arabicName
            .replaceAll('سُورَةُ', '')
            .replaceAll('سُورَة', '')
            .trim())
        .toList();

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0D08) : const Color(0xFFEDE8D5),
      drawer: _MushafDrawer(state: state, onGoToPage: onGoToPage),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.translucent,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: controller,
                    itemCount: _totalPages,
                    onPageChanged: (index) =>
                        context.read<MushafCubit>().setPage(index + 1),
                    itemBuilder: (context, index) {
                      return _MushafPageWidget(
                        pageNumber: index + 1,
                        state: state,
                        isDark: isDark,
                        selectedAyah: selectedAyah,
                        bottomInset: showControls ? 48.h : 0,
                      );
                    },
                  ),
                  if (showControls) ...[
                    _TopBar(state: state, isDark: isDark),
                    _BottomBar(state: state, isDark: isDark),
                  ],
                  // Swipe-down from top → show controls
                  _SwipeDownHandle(onSwipeDown: onTap),
                  if (!showPanel)
                    _SwipeUpHandle(isDark: isDark, onSwipeUp: onShowPanel),
                ],
              ),
            ),
          ),
          if (showPanel) ...[
            _AyahBar(mushafState: state),
            AudioPlayerSheet(surahNames: surahNames),
          ],
        ],
      ),
    );
  }
}

// ─── Ayah Bar ───

class _AyahBar extends StatefulWidget {
  final MushafReady mushafState;
  const _AyahBar({required this.mushafState});

  @override
  State<_AyahBar> createState() => _AyahBarState();
}

class _AyahBarState extends State<_AyahBar> {
  int? _surahId;
  int? _ayahNum;
  int _trackedPage = 0;

  List<MushafAyahEntity> _pageAyahs(BuildContext context) {
    final cubit = context.read<MushafCubit>();
    return cubit.getPageData(widget.mushafState.currentPage)?.ayahs ?? [];
  }

  void _initForPage(BuildContext context) {
    final ayahs = _pageAyahs(context);
    if (ayahs.isNotEmpty) {
      _surahId = ayahs.first.surahId;
      _ayahNum = ayahs.first.ayahNum;
    } else {
      _surahId = null;
      _ayahNum = null;
    }
    _trackedPage = widget.mushafState.currentPage;
  }

  @override
  void didUpdateWidget(_AyahBar old) {
    super.didUpdateWidget(old);
    if (widget.mushafState.currentPage != _trackedPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _initForPage(context));
      });
    }
  }

  void _goPrev(BuildContext context) {
    if (_surahId == null || _ayahNum == null) return;
    final ayahs = _pageAyahs(context);
    final idx = ayahs.indexWhere(
        (a) => a.surahId == _surahId && a.ayahNum == _ayahNum);
    if (idx > 0) {
      setState(() {
        _surahId = ayahs[idx - 1].surahId;
        _ayahNum = ayahs[idx - 1].ayahNum;
      });
    }
  }

  void _goNext(BuildContext context) {
    if (_surahId == null || _ayahNum == null) return;
    final ayahs = _pageAyahs(context);
    final idx = ayahs.indexWhere(
        (a) => a.surahId == _surahId && a.ayahNum == _ayahNum);
    if (idx >= 0 && idx < ayahs.length - 1) {
      setState(() {
        _surahId = ayahs[idx + 1].surahId;
        _ayahNum = ayahs[idx + 1].ayahNum;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_trackedPage == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _initForPage(context));
      });
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF1C1509) : const Color(0xFFFBF6E8);

    String label = '';
    if (_surahId != null && _ayahNum != null) {
      final surahName = widget.mushafState
          .surahInfo(_surahId!)
          .arabicName
          .replaceAll('سُورَةُ', '')
          .replaceAll('سُورَة', '')
          .trim();
      label = '$surahName  •  الآية ${_toArabicNum(_ayahNum!)}';
    }

    final ayahs = _surahId != null ? _pageAyahs(context) : <MushafAyahEntity>[];
    final idx = ayahs.indexWhere(
        (a) => a.surahId == _surahId && a.ayahNum == _ayahNum);
    final canPrev = idx > 0;
    final canNext = idx >= 0 && idx < ayahs.length - 1;

    return Container(
      height: 40.h,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: AppColors.gold, width: 1)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_forward_ios,
                size: 14.r,
                color: canPrev
                    ? context.colors.textPrimary
                    : context.colors.textSecondary),
            onPressed: canPrev ? () => _goPrev(context) : null,
            padding: EdgeInsets.zero,
          ),
          Expanded(
            child: GestureDetector(
              onTap: _surahId != null
                  ? () => _showAyahOptions(context)
                  : null,
              child: Text(
                label,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 13.sp,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.arrow_back_ios,
                size: 14.r,
                color: canNext
                    ? context.colors.textPrimary
                    : context.colors.textSecondary),
            onPressed: canNext ? () => _goNext(context) : null,
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  void _showAyahOptions(BuildContext context) {
    if (_surahId == null || _ayahNum == null) return;
    final mushafCubit = context.read<MushafCubit>();
    final audioCubit = context.read<QuranAudioCubit>();
    final surahName = widget.mushafState
        .surahInfo(_surahId!)
        .arabicName
        .replaceAll('سُورَةُ', '')
        .replaceAll('سُورَة', '')
        .trim();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: mushafCubit),
          BlocProvider.value(value: audioCubit),
        ],
        child: _AyahTapSheet(
          surahId: _surahId!,
          ayahNum: _ayahNum!,
          surahName: surahName,
          pageNum: widget.mushafState.currentPage,
          mushafState: widget.mushafState,
        ),
      ),
    );
  }
}

// ─── Ayah Tap Sheet ───

class _AyahTapSheet extends StatelessWidget {
  final int surahId;
  final int ayahNum;
  final String surahName;
  final int pageNum;
  final MushafReady mushafState;

  const _AyahTapSheet({
    required this.surahId,
    required this.ayahNum,
    required this.surahName,
    required this.pageNum,
    required this.mushafState,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A12) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFEBD9A6) : const Color(0xFF1A0A00);
    final textSec = isDark ? Colors.white54 : Colors.black45;
    final isBookmarked = mushafState.bookmarkFor(surahId, ayahNum) != null;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        border: Border(top: BorderSide(color: AppColors.gold, width: 1.5)),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 28.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
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
          SizedBox(height: 16.h),
          // Ornamental header
          Text(
            '﴾ سورة $surahName ﴿',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'ScheherazadeNew',
              fontSize: 20.sp,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'الآية ${_toArabicNum(ayahNum)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13.sp,
              color: textSec,
            ),
          ),
          SizedBox(height: 20.h),
          // Primary: play ayah
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<QuranAudioCubit>().playAyah(surahId, ayahNum);
            },
            icon: Icon(Icons.headphones_rounded, size: 20.r),
            label: Text(
              'استمع للآية الكريمة',
              style: TextStyle(fontSize: 15.sp, fontFamily: 'Cairo'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r)),
              elevation: 0,
            ),
          ),
          SizedBox(height: 10.h),
          // Secondary: play surah
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<QuranAudioCubit>().playSurah(surahId);
            },
            icon: Icon(Icons.queue_music_rounded, size: 18.r,
                color: AppColors.primary),
            label: Text(
              'استمع لسورة $surahName',
              style: TextStyle(
                  fontSize: 14.sp, fontFamily: 'Cairo', color: AppColors.primary),
            ),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              side: BorderSide(color: AppColors.primary.withAlpha(180)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r)),
            ),
          ),
          // Mini active player
          BlocBuilder<QuranAudioCubit, QuranAudioState>(
            buildWhen: (p, c) =>
                (p is QuranAudioPlaying) != (c is QuranAudioPlaying) ||
                (p is QuranAudioPaused) != (c is QuranAudioPaused) ||
                (p is QuranAudioPlaying && c is QuranAudioPlaying &&
                    (p.surahNum != c.surahNum || p.ayahNum != c.ayahNum)),
            builder: (context, audioState) {
              if (audioState is! QuranAudioPlaying &&
                  audioState is! QuranAudioPaused) {
                return const SizedBox.shrink();
              }
              final playing = audioState is QuranAudioPlaying ? audioState : null;
              final paused = audioState is QuranAudioPaused ? audioState : null;
              final isPlaying = playing != null;
              final sNum = playing?.surahNum ?? paused!.surahNum;
              final aNum = playing?.ayahNum ?? paused?.ayahNum;
              final isSurahMode = playing?.isSurah ?? paused?.isSurah ?? true;
              final reciterName =
                  playing?.reciter.arabicName ?? paused!.reciter.arabicName;
              final sName = mushafState.surahInfo(sNum).arabicName
                  .replaceAll('سُورَةُ', '').replaceAll('سُورَة', '').trim();
              final displayText = isSurahMode
                  ? sName
                  : '$sName  •  آية ${_toArabicNum(aNum ?? 1)}';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 14.h),
                  Divider(color: isDark ? Colors.white12 : Colors.black12),
                  SizedBox(height: 8.h),
                  Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Container(
                        width: 36.r,
                        height: 36.r,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Icon(Icons.music_note_rounded,
                            color: AppColors.primary, size: 18.r),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reciterName,
                              style: TextStyle(
                                  fontSize: 11.sp,
                                  color: textSec,
                                  fontFamily: 'Cairo'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              displayText,
                              style: TextStyle(
                                  fontSize: 12.sp,
                                  color: textPrimary,
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_filled_rounded,
                          color: AppColors.primary,
                          size: 32.r,
                        ),
                        onPressed: () {
                          if (isPlaying) {
                            context.read<QuranAudioCubit>().pause();
                          } else {
                            context.read<QuranAudioCubit>().resume();
                          }
                        },
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        icon: Icon(Icons.stop_circle_outlined,
                            color: textSec, size: 24.r),
                        onPressed: () {
                          context.read<QuranAudioCubit>().stop();
                          Navigator.of(context).pop();
                        },
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          SizedBox(height: 14.h),
          Divider(color: isDark ? Colors.white12 : Colors.black12),
          SizedBox(height: 8.h),
          // Action row
          Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _TapSheetAction(
                icon: isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                label: isBookmarked ? 'إزالة علامة' : 'إضافة علامة',
                color: isBookmarked ? AppColors.gold : null,
                onTap: () {
                  if (isBookmarked) {
                    context.read<MushafCubit>().removeBookmark(surahId, ayahNum);
                  } else {
                    context.read<MushafCubit>().addOrUpdateBookmark(
                          MushafBookmark(
                            surahId: surahId,
                            ayahNum: ayahNum,
                            pageNum: pageNum,
                            timestamp: DateTime.now().millisecondsSinceEpoch,
                          ),
                        );
                  }
                  Navigator.of(context).pop();
                },
              ),
              _TapSheetAction(
                icon: Icons.copy_rounded,
                label: 'نسخ',
                onTap: () {
                  Clipboard.setData(ClipboardData(
                      text: 'سورة $surahName آية ${_toArabicNum(ayahNum)}'));
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('تم النسخ',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(fontSize: 13.sp)),
                    duration: const Duration(seconds: 2),
                    backgroundColor: AppColors.primary,
                  ));
                },
              ),
              _TapSheetAction(
                icon: Icons.highlight_alt_rounded,
                label: 'تمييز / ملاحظة',
                onTap: () {
                  Navigator.of(context).pop();
                  final cubit = context.read<MushafCubit>();
                  final audioCubit = context.read<QuranAudioCubit>();
                  final pageData = cubit.getPageData(pageNum);
                  final ayahText = pageData?.ayahs
                          .where((a) =>
                              a.surahId == surahId && a.ayahNum == ayahNum)
                          .firstOrNull
                          ?.text ??
                      '';
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) => MultiBlocProvider(
                      providers: [
                        BlocProvider.value(value: cubit),
                        BlocProvider.value(value: audioCubit),
                      ],
                      child: _AyahActionSheet(
                        surahId: surahId,
                        verseNum: ayahNum,
                        ayahText: ayahText,
                        existing: mushafState.bookmarkFor(surahId, ayahNum),
                        surahName: surahName,
                        pageNumber: pageNum,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TapSheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _TapSheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48.r,
            height: 48.r,
            decoration: BoxDecoration(
              color: c.withAlpha(18),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: c, size: 22.r),
          ),
          SizedBox(height: 5.h),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
              fontSize: 10.sp,
              fontFamily: 'Cairo',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Top Bar ───

class _TopBar extends StatelessWidget {
  final MushafReady state;
  final bool isDark;

  const _TopBar({required this.state, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final page = context.read<MushafCubit>().getPageData(state.currentPage);
    final juz = page?.juzNumber ?? 1;
    final surahIds = page?.surahIds ?? [];
    final shortName = surahIds.isNotEmpty
        ? state
            .surahInfo(surahIds.last)
            .arabicName
            .replaceAll('سُورَةُ', '')
            .replaceAll('سُورَة', '')
            .trim()
        : '';

    final progress = (state.readingProgress * 100).toStringAsFixed(0);
    final isPageBookmarked = state.pageBookmarks.contains(state.currentPage);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          height: 48.h,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withAlpha(180),
                Colors.transparent,
              ],
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Scaffold.of(context).openDrawer(),
                child: Padding(
                  padding: EdgeInsets.all(8.r),
                  child: Icon(Icons.format_list_bulleted,
                      color: Colors.white, size: 20.r),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Padding(
                  padding: EdgeInsets.all(8.r),
                  child: Icon(Icons.close, color: Colors.white, size: 20.r),
                ),
              ),
              GestureDetector(
                onTap: () => context
                    .read<MushafCubit>()
                    .togglePageBookmark(state.currentPage),
                child: Padding(
                  padding: EdgeInsets.all(8.r),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isPageBookmarked
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      key: ValueKey(isPageBookmarked),
                      color: isPageBookmarked
                          ? AppColors.gold
                          : Colors.white.withAlpha(180),
                      size: 20.r,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  shortName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontFamily: 'ScheherazadeNew',
                    shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'الجزء ${_toArabicNum(juz)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.sp,
                      shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                  ),
                  Text(
                    '$progress٪ مكتمل',
                    style: TextStyle(
                        color: AppColors.goldLight, fontSize: 10.sp),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bottom Bar ───

class _BottomBar extends StatelessWidget {
  final MushafReady state;
  final bool isDark;

  const _BottomBar({required this.state, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final page = context.read<MushafCubit>().getPageData(state.currentPage);
    final pageBookmarks = page == null
        ? <MushafBookmark>[]
        : state.bookmarks
            .where((b) =>
                page.ayahs.any(
                    (a) => a.surahId == b.surahId && a.ayahNum == b.ayahNum))
            .toList();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          height: 48.h,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withAlpha(180),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (pageBookmarks.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(left: 16.w),
                  child: Row(
                    children: [
                      Icon(Icons.bookmark, color: AppColors.gold, size: 14.r),
                      SizedBox(width: 3.w),
                      Text(
                        '${pageBookmarks.length}',
                        style:
                            TextStyle(color: AppColors.gold, fontSize: 12.sp),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox.shrink(),
              Expanded(
                child: Text(
                  _toArabicNum(state.currentPage),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: 16.w),
                child: Text(
                  '${_toArabicNum(state.readPagesCount)} / ${_toArabicNum(_totalPages)}',
                  style: TextStyle(
                      color: Colors.white.withAlpha(180), fontSize: 11.sp),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Swipe Handles ───

class _SwipeDownHandle extends StatelessWidget {
  final VoidCallback onSwipeDown;
  const _SwipeDownHandle({required this.onSwipeDown});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 300) onSwipeDown();
        },
        child: SafeArea(child: SizedBox(height: 32.h)),
      ),
    );
  }
}



class _SwipeUpHandle extends StatelessWidget {
  final bool isDark;
  final VoidCallback onSwipeUp;

  const _SwipeUpHandle({required this.isDark, required this.onSwipeUp});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) < -300) onSwipeUp();
        },
        child: SafeArea(
          child: SizedBox(
            height: 28.h,
            child: Center(
              child: Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withAlpha(80),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Mushaf Page Widget ───

class _MushafPageWidget extends StatelessWidget {
  final int pageNumber;
  final MushafReady state;
  final bool isDark;
  final ValueNotifier<(int, int)?> selectedAyah;
  final double bottomInset;

  const _MushafPageWidget({
    required this.pageNumber,
    required this.state,
    required this.isDark,
    required this.selectedAyah,
    this.bottomInset = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Rebuilds only when playing ayah changes
    final playingAyah = context.select<QuranAudioCubit, (int, int)?>(
      (cubit) {
        final s = cubit.state;
        if (s is QuranAudioPlaying && !s.isSurah && s.ayahNum != null) {
          return (s.surahNum, s.ayahNum!);
        }
        return null;
      },
    );

    final pageBg = isDark ? const Color(0xFF1C1509) : const Color(0xFFFBF6E8);

    return ValueListenableBuilder<(int, int)?>(
      valueListenable: selectedAyah,
      builder: (ctx, selected, _) {
        // QcfPage must receive full screen width so line breaks match printed Mushaf.
        final qcfTheme = isDark
            ? QcfThemeData.dark().copyWith(
                pageBackgroundColor: const Color(0xFF1C1509),
                verseTextColor: const Color(0xFFEBD9A6),
                verseBackgroundColor: (s, v) =>
                    _verseHighlight(s, v, playingAyah, selected),
              )
            : QcfThemeData(
                verseTextColor: const Color(0xFF1A0A00),
                pageBackgroundColor: const Color(0xFFFBF6E8),
                verseBackgroundColor: (s, v) =>
                    _verseHighlight(s, v, playingAyah, selected),
              );

        return ColoredBox(
          color: pageBg,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: QcfPage(
              pageNumber: pageNumber,
              theme: qcfTheme,
              onTap: (surahNumber, verseNumber) =>
                  _onVerseTap(ctx, surahNumber, verseNumber),
              onLongPress: (surahNumber, verseNumber) =>
                  _onVerseLongPress(ctx, surahNumber, verseNumber),
            ),
          ),
        );
      },
    );
  }

  Color? _verseHighlight(
      int surahId, int verseNum, (int, int)? playingAyah, (int, int)? selected) {
    // Selected ayah (tapped) gets a distinct gold highlight
    if (selected != null && selected.$1 == surahId && selected.$2 == verseNum) {
      return isDark
          ? const Color(0xFFFFD700).withAlpha(90)
          : const Color(0xFFFFD700).withAlpha(160);
    }
    // Playing ayah highlight
    if (playingAyah != null &&
        playingAyah.$1 == surahId &&
        playingAyah.$2 == verseNum) {
      return isDark
          ? const Color(0xFFFFD700).withAlpha(65)
          : const Color(0xFFFFF176).withAlpha(210);
    }
    final bookmark = state.bookmarkFor(surahId, verseNum);
    if (bookmark == null) return null;
    return _highlightColors[bookmark.colorIndex]?.withAlpha(130);
  }

  void _onVerseTap(BuildContext context, int surahNumber, int verseNumber) {
    final cubit = context.read<MushafCubit>();
    final audioCubit = context.read<QuranAudioCubit>();
    final st = cubit.state;
    if (st is! MushafReady) return;

    final surahName = st
        .surahInfo(surahNumber)
        .arabicName
        .replaceAll('سُورَةُ', '')
        .replaceAll('سُورَة', '')
        .trim();

    selectedAyah.value = (surahNumber, verseNumber);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: cubit),
          BlocProvider.value(value: audioCubit),
        ],
        child: _AyahTapSheet(
          surahId: surahNumber,
          ayahNum: verseNumber,
          surahName: surahName,
          pageNum: st.currentPage,
          mushafState: st,
        ),
      ),
    ).then((_) => selectedAyah.value = null);
  }

  void _onVerseLongPress(
      BuildContext context, int surahNumber, int verseNumber) {
    final cubit = context.read<MushafCubit>();
    final st = cubit.state;
    if (st is! MushafReady) return;

    final bookmark = st.bookmarkFor(surahNumber, verseNumber);
    final surahName = st
        .surahInfo(surahNumber)
        .arabicName
        .replaceAll('سُورَةُ', '')
        .replaceAll('سُورَة', '')
        .trim();

    final pageData = cubit.getPageData(st.currentPage);
    final ayahText = pageData?.ayahs
            .where((a) =>
                a.surahId == surahNumber && a.ayahNum == verseNumber)
            .firstOrNull
            ?.text ??
        '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _AyahActionSheet(
          surahId: surahNumber,
          verseNum: verseNumber,
          ayahText: ayahText,
          existing: bookmark,
          surahName: surahName,
          pageNumber: st.currentPage,
        ),
      ),
    );
  }
}

// ─── Ayah Action Sheet ───

class _AyahActionSheet extends StatefulWidget {
  final int surahId;
  final int verseNum;
  final String ayahText;
  final MushafBookmark? existing;
  final String surahName;
  final int pageNumber;

  const _AyahActionSheet({
    required this.surahId,
    required this.verseNum,
    required this.ayahText,
    required this.existing,
    required this.surahName,
    required this.pageNumber,
  });

  @override
  State<_AyahActionSheet> createState() => _AyahActionSheetState();
}

class _AyahActionSheetState extends State<_AyahActionSheet> {
  late int _selectedColor;
  late TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.existing?.colorIndex ?? 0;
    _noteCtrl = TextEditingController(text: widget.existing?.note ?? '');
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  static const _colorLabels = ['إشارة فقط', 'أصفر', 'أخضر', 'أزرق', 'وردي'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A12) : Colors.white;
    final textPrimary =
        isDark ? const Color(0xFFEBD9A6) : const Color(0xFF1A0A00);
    final textSec = isDark ? Colors.white54 : Colors.black45;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          border: Border(
            top: BorderSide(color: AppColors.gold, width: 1.5),
          ),
        ),
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            SizedBox(height: 12.h),
            Text(
              '${widget.surahName}  •  آية ${_toArabicNum(widget.verseNum)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.ayahText.isNotEmpty) ...[
              SizedBox(height: 6.h),
              Text(
                widget.ayahText.length > 60
                    ? '${widget.ayahText.substring(0, 60)}...'
                    : widget.ayahText,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'ScheherazadeNew',
                  fontSize: 16.sp,
                  color: textPrimary,
                  height: 1.8,
                ),
              ),
            ],
            SizedBox(height: 16.h),
            Text('نوع التمييز',
                style: TextStyle(color: textSec, fontSize: 12.sp)),
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (i) {
                final isSelected = _selectedColor == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 48.r,
                    height: 48.r,
                    decoration: BoxDecoration(
                      color: i == 0
                          ? (isDark
                              ? const Color(0xFF2A2A1A)
                              : const Color(0xFFF5F0E0))
                          : _highlightColors[i]!.withAlpha(isSelected ? 255 : 130),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (i == 0)
                          Icon(Icons.bookmark,
                              size: 16.r, color: AppColors.gold),
                        if (isSelected)
                          Icon(Icons.check,
                              size: 12.r, color: AppColors.primary),
                      ],
                    ),
                  ),
                );
              }),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (i) {
                return SizedBox(
                  width: 48.r,
                  child: Text(
                    _colorLabels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textSec, fontSize: 9.sp),
                  ),
                );
              }),
            ),
            SizedBox(height: 16.h),
            Text('ملاحظة (اختياري)',
                style: TextStyle(color: textSec, fontSize: 12.sp)),
            SizedBox(height: 6.h),
            TextField(
              controller: _noteCtrl,
              textDirection: TextDirection.rtl,
              maxLines: 2,
              style: TextStyle(fontSize: 14.sp, color: textPrimary),
              decoration: InputDecoration(
                hintText: 'اكتب ملاحظتك هنا...',
                hintStyle: TextStyle(color: textSec, fontSize: 13.sp),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF252515)
                    : const Color(0xFFF5F0E0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide:
                      BorderSide(color: AppColors.gold.withAlpha(80)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide:
                      BorderSide(color: AppColors.gold.withAlpha(60)),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                if (widget.existing != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _remove,
                      icon: Icon(Icons.delete_outline,
                          size: 16.r, color: AppColors.error),
                      label: Text('إزالة',
                          style: TextStyle(
                              color: AppColors.error, fontSize: 13.sp)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: AppColors.error.withAlpha(80)),
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r)),
                      ),
                    ),
                  ),
                if (widget.existing != null) SizedBox(width: 10.w),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r)),
                    ),
                    child: Text(
                      widget.existing == null ? 'حفظ' : 'تحديث',
                      style: TextStyle(fontSize: 14.sp),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final cubit = context.read<MushafCubit>();
    cubit.addOrUpdateBookmark(MushafBookmark(
      surahId: widget.surahId,
      ayahNum: widget.verseNum,
      pageNum: widget.pageNumber,
      note: _noteCtrl.text.trim(),
      colorIndex: _selectedColor,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
    Navigator.of(context).pop();
  }

  void _remove() {
    context.read<MushafCubit>().removeBookmark(widget.surahId, widget.verseNum);
    Navigator.of(context).pop();
  }
}

// ─── Mushaf Drawer ───

const _juzNames = [
  'الجزء الأول', 'الجزء الثاني', 'الجزء الثالث', 'الجزء الرابع',
  'الجزء الخامس', 'الجزء السادس', 'الجزء السابع', 'الجزء الثامن',
  'الجزء التاسع', 'الجزء العاشر', 'الجزء الحادي عشر', 'الجزء الثاني عشر',
  'الجزء الثالث عشر', 'الجزء الرابع عشر', 'الجزء الخامس عشر',
  'الجزء السادس عشر', 'الجزء السابع عشر', 'الجزء الثامن عشر',
  'الجزء التاسع عشر', 'الجزء العشرون', 'الجزء الحادي والعشرون',
  'الجزء الثاني والعشرون', 'الجزء الثالث والعشرون', 'الجزء الرابع والعشرون',
  'الجزء الخامس والعشرون', 'الجزء السادس والعشرون', 'الجزء السابع والعشرون',
  'الجزء الثامن والعشرون', 'الجزء التاسع والعشرون', 'الجزء الثلاثون',
];

class _MushafDrawer extends StatelessWidget {
  final MushafReady state;
  final void Function(int page) onGoToPage;

  const _MushafDrawer({required this.state, required this.onGoToPage});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1509) : const Color(0xFFFBF6E8);
    final textSec = isDark ? Colors.white54 : Colors.black45;

    void navigate(int page) {
      Navigator.of(context).pop();
      onGoToPage(page);
    }

    return Drawer(
      backgroundColor: bg,
      width: 0.82.sw,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.menu_book_rounded,
                      color: AppColors.goldLight, size: 20.r),
                  SizedBox(width: 8.w),
                  Text(
                    'المصحف الشريف',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'ScheherazadeNew',
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(Icons.close,
                        color: Colors.white.withAlpha(200), size: 20.r),
                  ),
                ],
              ),
            ),
            Expanded(
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    TabBar(
                      labelColor: AppColors.primary,
                      unselectedLabelColor: textSec,
                      indicatorColor: AppColors.gold,
                      indicatorWeight: 2,
                      labelStyle: TextStyle(
                          fontSize: 12.sp, fontWeight: FontWeight.w600),
                      unselectedLabelStyle: TextStyle(fontSize: 12.sp),
                      tabs: const [
                        Tab(text: 'معلماتي'),
                        Tab(text: 'الأجزاء'),
                        Tab(text: 'السور'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _BookmarksTab(
                              state: state,
                              onNavigate: navigate,
                              isDark: isDark),
                          _JuzTab(
                              state: state,
                              onNavigate: navigate,
                              isDark: isDark),
                          _SurahsTab(
                              state: state,
                              onNavigate: navigate,
                              isDark: isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookmarksTab extends StatelessWidget {
  final MushafReady state;
  final void Function(int page) onNavigate;
  final bool isDark;

  const _BookmarksTab(
      {required this.state, required this.onNavigate, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final sorted = state.pageBookmarks.toList()..sort();
    final textPrimary =
        isDark ? const Color(0xFFEBD9A6) : const Color(0xFF1A0A00);
    final textSec = isDark ? Colors.white54 : Colors.black45;

    if (sorted.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border, color: textSec, size: 40.r),
            SizedBox(height: 12.h),
            Text(
              'لا توجد صفحات معلمة بعد\nاضغط على أيقونة العلامة في أعلى الصفحة',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: textSec, fontSize: 13.sp, height: 1.6),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      itemCount: sorted.length,
      itemBuilder: (context, i) {
        final page = sorted[i];
        final cubit = context.read<MushafCubit>();
        final pageData = cubit.getPageData(page);
        final surahName = pageData != null && pageData.ayahs.isNotEmpty
            ? state
                .surahInfo(pageData.ayahs.first.surahId)
                .arabicName
                .replaceAll('سُورَةُ', '')
                .replaceAll('سُورَة', '')
                .trim()
            : '';

        return ListTile(
          dense: true,
          onTap: () => onNavigate(page),
          leading: Icon(Icons.bookmark, color: AppColors.gold, size: 20.r),
          title: Text(
            'صفحة ${_toArabicNum(page)}',
            style: TextStyle(
                color: textPrimary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600),
          ),
          subtitle: surahName.isNotEmpty
              ? Text(surahName,
                  style: TextStyle(
                      color: textSec,
                      fontSize: 12.sp,
                      fontFamily: 'ScheherazadeNew'))
              : null,
          trailing: Icon(Icons.arrow_back_ios, size: 14.r, color: textSec),
        );
      },
    );
  }
}

class _JuzTab extends StatelessWidget {
  final MushafReady state;
  final void Function(int page) onNavigate;
  final bool isDark;

  const _JuzTab(
      {required this.state, required this.onNavigate, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? const Color(0xFFEBD9A6) : const Color(0xFF1A0A00);
    final textSec = isDark ? Colors.white54 : Colors.black45;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;

    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      itemCount: 30,
      separatorBuilder: (_, _) => Divider(height: 1, color: dividerColor),
      itemBuilder: (context, i) {
        final juz = i + 1;
        final page = state.juzFirstPages[juz] ?? 1;
        final isCurrentJuz =
            (context.read<MushafCubit>().getPageData(state.currentPage)?.juzNumber ?? 1) == juz;

        return ListTile(
          dense: true,
          onTap: () => onNavigate(page),
          leading: Container(
            width: 32.r,
            height: 32.r,
            decoration: BoxDecoration(
              color: isCurrentJuz
                  ? AppColors.primary
                  : AppColors.primary.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _toArabicNum(juz),
                style: TextStyle(
                  color: isCurrentJuz ? Colors.white : AppColors.primary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          title: Text(
            _juzNames[i],
            style: TextStyle(
              color: isCurrentJuz ? AppColors.primary : textPrimary,
              fontSize: 13.sp,
              fontWeight:
                  isCurrentJuz ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          subtitle: Text(
            'صفحة ${_toArabicNum(page)}',
            style: TextStyle(color: textSec, fontSize: 11.sp),
          ),
          trailing: isCurrentJuz
              ? Icon(Icons.play_arrow, color: AppColors.primary, size: 16.r)
              : Icon(Icons.arrow_back_ios, size: 14.r, color: textSec),
        );
      },
    );
  }
}

class _SurahsTab extends StatelessWidget {
  final MushafReady state;
  final void Function(int page) onNavigate;
  final bool isDark;

  const _SurahsTab(
      {required this.state, required this.onNavigate, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? const Color(0xFFEBD9A6) : const Color(0xFF1A0A00);
    final textSec = isDark ? Colors.white54 : Colors.black45;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;

    final pageData = context.read<MushafCubit>().getPageData(state.currentPage);
    final currentSurahIds = pageData?.surahIds ?? [];

    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      itemCount: state.surahInfos.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: dividerColor),
      itemBuilder: (context, i) {
        final info = state.surahInfos[i];
        final page = state.surahFirstPages[info.id] ?? 1;
        final shortName = info.arabicName
            .replaceAll('سُورَةُ', '')
            .replaceAll('سُورَة', '')
            .trim();
        final isCurrentSurah = currentSurahIds.contains(info.id);
        final typeLabel = info.type == 'meccan' ? 'مكية' : 'مدنية';

        return ListTile(
          dense: true,
          onTap: () => onNavigate(page),
          leading: SizedBox(
            width: 32.r,
            height: 32.r,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.star_outline_rounded,
                  color: isCurrentSurah ? AppColors.primary : AppColors.gold,
                  size: 32.r,
                ),
                Text(
                  _toArabicNum(info.id),
                  style: TextStyle(
                    color:
                        isCurrentSurah ? AppColors.primary : AppColors.gold,
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          title: Text(
            shortName,
            style: TextStyle(
              fontFamily: 'ScheherazadeNew',
              color: isCurrentSurah ? AppColors.primary : textPrimary,
              fontSize: 15.sp,
              fontWeight:
                  isCurrentSurah ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          subtitle: Text(
            '$typeLabel  •  ${_toArabicNum(info.verseCount)} آية  •  ص ${_toArabicNum(page)}',
            style: TextStyle(color: textSec, fontSize: 10.sp),
          ),
          trailing: isCurrentSurah
              ? Icon(Icons.play_arrow, color: AppColors.primary, size: 16.r)
              : Icon(Icons.arrow_back_ios, size: 14.r, color: textSec),
        );
      },
    );
  }
}

// ─── Loading / Error ───

class _LoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFBF6E8),
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      appBar: AppBar(backgroundColor: AppColors.primary),
      body: Center(
        child: Text(message,
            style: TextStyle(
                color: context.colors.textPrimary, fontSize: 14.sp)),
      ),
    );
  }
}
