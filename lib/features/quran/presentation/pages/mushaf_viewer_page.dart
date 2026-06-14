import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/mushaf_entities.dart';
import '../../domain/utils/tajweed_colorizer.dart';
import '../cubit/mushaf_cubit.dart';

// ─── Constants ───

const _bismillah = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';
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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<MushafCubit>()
        ..initialize(startPage: widget.initialPage),
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
  bool _showControls = true;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MushafCubit, MushafState>(
      listenWhen: (prev, curr) =>
          prev is MushafLoading && curr is MushafReady,
      listener: (context, state) {
        if (state is MushafReady) {
          int startPage = state.currentPage;
          if (widget.surahId != null) {
            startPage =
                state.surahFirstPages[widget.surahId!] ?? startPage;
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
            onTap: () => setState(() => _showControls = !_showControls),
          );
        }
        return _LoadingView();
      },
    );
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }
}

// ─── Reader View ───

class _ReaderView extends StatelessWidget {
  final MushafReady state;
  final PageController controller;
  final bool showControls;
  final VoidCallback onTap;

  const _ReaderView({
    required this.state,
    required this.controller,
    required this.showControls,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0D08) : const Color(0xFFEDE8D5),
      body: GestureDetector(
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
                final pageData =
                    context.read<MushafCubit>().getPageData(index + 1);
                if (pageData == null) return const SizedBox.shrink();
                return _MushafPageWidget(
                  pageData: pageData,
                  state: state,
                  isDark: isDark,
                );
              },
            ),
            if (showControls) ...[
              _TopBar(state: state, isDark: isDark),
              _BottomBar(state: state, isDark: isDark),
            ],
          ],
        ),
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
                onTap: () => Navigator.of(context).pop(),
                child: Padding(
                  padding: EdgeInsets.all(8.r),
                  child: Icon(Icons.close, color: Colors.white, size: 20.r),
                ),
              ),
              // Tajweed toggle
              GestureDetector(
                onTap: () => context.read<MushafCubit>().toggleTajweed(),
                child: Padding(
                  padding: EdgeInsets.all(8.r),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      state.tajweedMode
                          ? Icons.color_lens
                          : Icons.color_lens_outlined,
                      key: ValueKey(state.tajweedMode),
                      color: state.tajweedMode
                          ? AppColors.goldLight
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
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 4)
                    ],
                  ),
                ),
              ),
              // Progress + Juz
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'الجزء ${_toArabicNum(juz)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.sp,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 4)
                      ],
                    ),
                  ),
                  Text(
                    '$progress٪ مكتمل',
                    style: TextStyle(
                      color: AppColors.goldLight,
                      fontSize: 10.sp,
                    ),
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
    // Check if current page has bookmarks
    final page =
        context.read<MushafCubit>().getPageData(state.currentPage);
    final pageBookmarks = page == null
        ? <MushafBookmark>[]
        : state.bookmarks
            .where((b) =>
                page.ayahs.any((a) =>
                    a.surahId == b.surahId && a.ayahNum == b.ayahNum))
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
              // Bookmarks count on this page
              if (pageBookmarks.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(left: 16.w),
                  child: Row(
                    children: [
                      Icon(Icons.bookmark,
                          color: AppColors.gold, size: 14.r),
                      SizedBox(width: 3.w),
                      Text(
                        '${pageBookmarks.length}',
                        style: TextStyle(
                            color: AppColors.gold, fontSize: 12.sp),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox.shrink(),
              // Page number (center)
              Expanded(
                child: Text(
                  _toArabicNum(state.currentPage),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 4)
                    ],
                  ),
                ),
              ),
              // Total read count
              Padding(
                padding: EdgeInsets.only(right: 16.w),
                child: Text(
                  '${_toArabicNum(state.readPagesCount)} / ${_toArabicNum(_totalPages)}',
                  style: TextStyle(
                    color: Colors.white.withAlpha(180),
                    fontSize: 11.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mushaf Page Widget ───

class _MushafPageWidget extends StatelessWidget {
  final MushafPageEntity pageData;
  final MushafReady state;
  final bool isDark;

  const _MushafPageWidget({
    required this.pageData,
    required this.state,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final pageBg =
        isDark ? const Color(0xFF1C1509) : const Color(0xFFFBF6E8);
    final textColor =
        isDark ? const Color(0xFFEBD9A6) : const Color(0xFF1A0A00);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        8.w,
        MediaQuery.paddingOf(context).top + 48.h + 4.h,
        8.w,
        MediaQuery.paddingOf(context).bottom + 48.h + 4.h,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: pageBg,
          border: Border.all(color: AppColors.primary, width: 2.5.r),
        ),
        child: Container(
          margin: EdgeInsets.all(3.r),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.gold, width: 0.8.r),
          ),
          child: _PageContent(
            pageData: pageData,
            state: state,
            isDark: isDark,
            textColor: textColor,
          ),
        ),
      ),
    );
  }
}

// ─── Page Content ───

class _PageContent extends StatelessWidget {
  final MushafPageEntity pageData;
  final MushafReady state;
  final bool isDark;
  final Color textColor;

  const _PageContent({
    required this.pageData,
    required this.state,
    required this.isDark,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    if (pageData.hasLines) {
      return _LineBasedContent(
        pageData: pageData,
        isDark: isDark,
        textColor: textColor,
      );
    }
    return _AyahBasedContent(
      pageData: pageData,
      state: state,
      isDark: isDark,
      textColor: textColor,
    );
  }
}

// ─── Line-based rendering (exact Mushaf layout when quran_lines.json exists) ───

class _LineBasedContent extends StatelessWidget {
  final MushafPageEntity pageData;
  final bool isDark;
  final Color textColor;

  const _LineBasedContent({
    required this.pageData,
    required this.isDark,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final lines = pageData.lines!;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final count = lines.length.clamp(1, 20);
          final lineH = constraints.maxHeight / count;
          final fontSize = (lineH * 0.50).clamp(14.0, 28.0);

          return Column(
            children: lines.map((line) {
              final isSurahName = line.type == MushafLineType.surahName;
              final isBasmala = line.type == MushafLineType.basmala;
              final isSpecial = isSurahName || isBasmala;

              Color lineColor = textColor;
              FontWeight weight = FontWeight.w400;

              if (isSurahName) {
                lineColor = isDark ? AppColors.goldLight : AppColors.primaryDark;
                weight = FontWeight.w700;
              } else if (isBasmala) {
                weight = FontWeight.w500;
              }

              return SizedBox(
                height: lineH,
                child: Center(
                  child: Text(
                    line.text,
                    textAlign: line.isCentered || isSpecial
                        ? TextAlign.center
                        : TextAlign.justify,
                    textDirection: TextDirection.rtl,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      fontFamily: 'ScheherazadeNew',
                      fontSize: isSpecial ? fontSize * 0.95 : fontSize,
                      color: lineColor,
                      fontWeight: weight,
                      height: 1.0,
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

// ─── Ayah-based rendering (fallback when only quran_pages.json is available) ───

class _AyahBasedContent extends StatelessWidget {
  final MushafPageEntity pageData;
  final MushafReady state;
  final bool isDark;
  final Color textColor;

  const _AyahBasedContent({
    required this.pageData,
    required this.state,
    required this.isDark,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final surahIds = pageData.surahIds;
    final sections = <Widget>[];

    for (final surahId in surahIds) {
      final ayahs = pageData.ayahsForSurah(surahId);
      final info = state.surahInfo(surahId);
      final startsHere = ayahs.first.ayahNum == 1;

      if (startsHere) {
        sections.add(_SurahHeader(info: info, isDark: isDark));
        if (surahId != 1 && surahId != 9) {
          sections.add(_BismillahLine(textColor: textColor));
        }
      }

      sections.add(Expanded(
        flex: ayahs.length,
        child: _AyahsBlock(
          ayahs: ayahs,
          textColor: textColor,
          fontSize: 20.sp,
          state: state,
          tajweedMode: state.tajweedMode,
        ),
      ));
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: sections,
      ),
    );
  }
}

// ─── Surah Header ───

class _SurahHeader extends StatelessWidget {
  final MushafSurahInfo info;
  final bool isDark;

  const _SurahHeader({required this.info, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final shortName = info.arabicName
        .replaceAll('سُورَةُ', '')
        .replaceAll('سُورَة', '')
        .trim();
    final typeLabel = info.type == 'meccan' ? 'مكية' : 'مدنية';

    return Container(
      margin: EdgeInsets.symmetric(vertical: 6.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A3A18), const Color(0xFF243222)]
              : [
                  AppColors.primary.withAlpha(30),
                  AppColors.primary.withAlpha(15)
                ],
        ),
        border: const Border(
          top: BorderSide(color: AppColors.gold, width: 0.8),
          bottom: BorderSide(color: AppColors.gold, width: 0.8),
        ),
      ),
      padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 8.w),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('❁',
                  style:
                      TextStyle(color: AppColors.gold, fontSize: 10.sp)),
              SizedBox(width: 8.w),
              Text(
                shortName,
                style: TextStyle(
                  fontFamily: 'ScheherazadeNew',
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.goldLight
                      : AppColors.primaryDark,
                ),
              ),
              SizedBox(width: 8.w),
              Text('❁',
                  style:
                      TextStyle(color: AppColors.gold, fontSize: 10.sp)),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            '$typeLabel  •  ${_toArabicNum(info.verseCount)} آية',
            style: TextStyle(
              fontSize: 11.sp,
              color: isDark
                  ? AppColors.goldLight.withAlpha(180)
                  : AppColors.primaryDark.withAlpha(180),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bismillah ───

class _BismillahLine extends StatelessWidget {
  final Color textColor;
  const _BismillahLine({required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Text(
        _bismillah,
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: 'ScheherazadeNew',
          fontSize: 20.sp,
          color: textColor,
          height: 1.9,
        ),
      ),
    );
  }
}

// ─── Ayahs Block (interactive) ───

class _AyahsBlock extends StatefulWidget {
  final List<MushafAyahEntity> ayahs;
  final Color textColor;
  final double fontSize;
  final MushafReady state;
  final bool tajweedMode;

  const _AyahsBlock({
    required this.ayahs,
    required this.textColor,
    required this.fontSize,
    required this.state,
    required this.tajweedMode,
  });

  @override
  State<_AyahsBlock> createState() => _AyahsBlockState();
}

class _AyahsBlockState extends State<_AyahsBlock> {
  final Map<int, LongPressGestureRecognizer> _recognizers = {};
  double? _cachedLineHeight;

  @override
  void initState() {
    super.initState();
    for (final ayah in widget.ayahs) {
      _recognizers[ayah.ayahNum] = LongPressGestureRecognizer()
        ..onLongPress = () => _onAyahTap(ayah);
    }
  }

  @override
  void dispose() {
    for (final r in _recognizers.values) {
      r.dispose();
    }
    super.dispose();
  }

  double _lineHeightFor(BoxConstraints c) {
    if (_cachedLineHeight != null) return _cachedLineHeight!;
    if (c.maxHeight == double.infinity || c.maxHeight <= 0) return 2.0;

    final plainText = widget.ayahs.map((a) => a.text).join(' ');
    final tp = TextPainter(
      text: TextSpan(
        text: plainText,
        style: TextStyle(
          fontFamily: 'ScheherazadeNew',
          fontSize: widget.fontSize,
          height: 2.0,
        ),
      ),
      textDirection: TextDirection.rtl,
      maxLines: null,
    )..layout(maxWidth: c.maxWidth);

    final nat = tp.height;
    if (nat <= 0 || nat >= c.maxHeight) return 2.0;
    _cachedLineHeight = (2.0 * c.maxHeight / nat).clamp(1.7, 3.2);
    return _cachedLineHeight!;
  }

  void _onAyahTap(MushafAyahEntity ayah) {
    final cubit = context.read<MushafCubit>();
    final st = cubit.state;
    if (st is! MushafReady) return;
    final bookmark = st.bookmarkFor(ayah.surahId, ayah.ayahNum);
    final surahName = st
        .surahInfo(ayah.surahId)
        .arabicName
        .replaceAll('سُورَةُ', '')
        .replaceAll('سُورَة', '')
        .trim();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _AyahActionSheet(
          ayah: ayah,
          existing: bookmark,
          surahName: surahName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final spans = <InlineSpan>[];

    for (final ayah in widget.ayahs) {
      final bookmark = widget.state.bookmarkFor(ayah.surahId, ayah.ayahNum);
      final highlightColor = bookmark != null
          ? _highlightColors[bookmark.colorIndex]?.withAlpha(130)
          : null;

      // Verse text — long press opens action sheet
      if (widget.tajweedMode) {
        spans.add(TextSpan(
          recognizer: _recognizers[ayah.ayahNum],
          children: [
            TajweedColorizer.build(
              text: ayah.text,
              baseColor: widget.textColor,
              isDark: isDark,
              backgroundColor: highlightColor,
            ),
          ],
        ));
      } else {
        spans.add(TextSpan(
          text: ayah.text,
          recognizer: _recognizers[ayah.ayahNum],
          style: TextStyle(backgroundColor: highlightColor),
        ));
      }

      // Verse number as circular badge outside the text flow
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _AyahNumberBadge(
          number: ayah.ayahNum,
          hasBookmark: bookmark != null && bookmark.colorIndex == 0,
        ),
      ));
    }

    final baseStyle = TextStyle(
      fontFamily: 'ScheherazadeNew',
      fontSize: widget.fontSize,
      color: widget.textColor,
    );

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final lineH = _lineHeightFor(constraints);
        return Text.rich(
          TextSpan(children: spans),
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
          style: baseStyle.copyWith(height: lineH),
        );
      },
    );
  }
}

// ─── Ayah Number Badge ───

class _AyahNumberBadge extends StatelessWidget {
  final int number;
  final bool hasBookmark;
  const _AyahNumberBadge({required this.number, required this.hasBookmark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      width: 22.r,
      height: 22.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold, width: 0.8),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              _toArabicNum(number),
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 8.sp,
                height: 1.0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (hasBookmark)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 6.r,
                height: 6.r,
                decoration: const BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Ayah Action Sheet ───

class _AyahActionSheet extends StatefulWidget {
  final MushafAyahEntity ayah;
  final MushafBookmark? existing;
  final String surahName;

  const _AyahActionSheet({
    required this.ayah,
    required this.existing,
    required this.surahName,
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
    _noteCtrl =
        TextEditingController(text: widget.existing?.note ?? '');
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  static const _colorLabels = [
    'إشارة فقط',
    'أصفر',
    'أخضر',
    'أزرق',
    'وردي',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A12) : Colors.white;
    final textPrimary =
        isDark ? const Color(0xFFEBD9A6) : const Color(0xFF1A0A00);
    final textSec = isDark ? Colors.white54 : Colors.black45;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20.r)),
          border: Border(
            top: BorderSide(color: AppColors.gold, width: 1.5),
          ),
        ),
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
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

            // Verse info
            Text(
              '${widget.surahName}  •  آية ${_toArabicNum(widget.ayah.ayahNum)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              widget.ayah.text.length > 60
                  ? '${widget.ayah.text.substring(0, 60)}...'
                  : widget.ayah.text,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'ScheherazadeNew',
                fontSize: 16.sp,
                color: textPrimary,
                height: 1.8,
              ),
            ),
            SizedBox(height: 16.h),

            // Color / type selector
            Text('نوع التمييز',
                style: TextStyle(
                    color: textSec, fontSize: 12.sp)),
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
                              size: 16.r, color: AppColors.gold)
                        else
                          const SizedBox.shrink(),
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
                    style: TextStyle(
                      color: textSec,
                      fontSize: 9.sp,
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: 16.h),

            // Note
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

            // Action buttons
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
                        side: BorderSide(color: AppColors.error.withAlpha(80)),
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
    final state = cubit.state;
    if (state is! MushafReady) return;
    final pageData =
        cubit.getPageData(state.currentPage);
    final pageNum = pageData?.pageNumber ?? 1;

    cubit.addOrUpdateBookmark(MushafBookmark(
      surahId: widget.ayah.surahId,
      ayahNum: widget.ayah.ayahNum,
      pageNum: pageNum,
      note: _noteCtrl.text.trim(),
      colorIndex: _selectedColor,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
    Navigator.of(context).pop();
  }

  void _remove() {
    context
        .read<MushafCubit>()
        .removeBookmark(widget.ayah.surahId, widget.ayah.ayahNum);
    Navigator.of(context).pop();
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
