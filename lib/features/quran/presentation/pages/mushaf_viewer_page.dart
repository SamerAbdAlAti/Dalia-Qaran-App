import 'dart:math';

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
const _quranFont = 'AmiriQuran'; // Uthmani-style Quran font (Aliftype, OFL license)

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

  void _goToPage(int page) {
    _pageController?.jumpToPage(page - 1);
  }

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
            onGoToPage: _goToPage,
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
  final void Function(int page) onGoToPage;

  const _ReaderView({
    required this.state,
    required this.controller,
    required this.showControls,
    required this.onTap,
    required this.onGoToPage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0D08) : const Color(0xFFEDE8D5),
      drawer: _MushafDrawer(state: state, onGoToPage: onGoToPage),
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
              // Menu button — opens drawer (rightmost in RTL = start side)
              GestureDetector(
                onTap: () => Scaffold.of(context).openDrawer(),
                child: Padding(
                  padding: EdgeInsets.all(8.r),
                  child: Icon(Icons.format_list_bulleted, color: Colors.white, size: 20.r),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Padding(
                  padding: EdgeInsets.all(8.r),
                  child: Icon(Icons.close, color: Colors.white, size: 20.r),
                ),
              ),
              // Page bookmark toggle
              GestureDetector(
                onTap: () => context.read<MushafCubit>().togglePageBookmark(state.currentPage),
                child: Padding(
                  padding: EdgeInsets.all(8.r),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isPageBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      key: ValueKey(isPageBookmarked),
                      color: isPageBookmarked ? AppColors.gold : Colors.white.withAlpha(180),
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
        tajweedMode: state.tajweedMode,
        fontWeight: state.fontWeight,
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

// ─── Helpers for line text ───

// Matches ayah end markers: optional ۝ (U+06DD) followed by Arabic-Indic digits
// The ۝ prefix is added by the generation script; older data may have digits only.
final _ayahMarkerPattern = RegExp(r'۝?[٠-٩]+');

int _arabicIndicToInt(String s) {
  const digits = '٠١٢٣٤٥٦٧٨٩';
  // Strip ۝ if present, then convert digits
  final cleaned = s.replaceAll('۝', '');
  return int.parse(
    cleaned.split('').map((c) {
      final i = digits.indexOf(c);
      return i >= 0 ? '$i' : c;
    }).join(),
    radix: 10,
  );
}

List<InlineSpan> _buildLineSpans({
  required String text,
  required TextStyle baseStyle,
  required double badgeSize,
  bool tajweedMode = false,
  bool isDark = false,
}) {
  final spans = <InlineSpan>[];
  int last = 0;

  for (final m in _ayahMarkerPattern.allMatches(text)) {
    if (m.start > last) {
      final segment = text.substring(last, m.start);
      if (tajweedMode) {
        spans.add(TajweedColorizer.build(
          text: segment,
          baseColor: baseStyle.color ?? Colors.black,
          isDark: isDark,
        ));
      } else {
        spans.add(TextSpan(text: segment, style: baseStyle));
      }
    }
    spans.add(WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: _AyahEndBadge(
        number: _arabicIndicToInt(m.group(0)!),
        size: badgeSize,
      ),
    ));
    last = m.end;
  }
  if (last < text.length) {
    final segment = text.substring(last);
    if (tajweedMode) {
      spans.add(TajweedColorizer.build(
        text: segment,
        baseColor: baseStyle.color ?? Colors.black,
        isDark: isDark,
      ));
    } else {
      spans.add(TextSpan(text: segment, style: baseStyle));
    }
  }
  return spans;
}

// ─── Line-based rendering (exact Mushaf layout when quran_lines.json exists) ───

class _LineBasedContent extends StatelessWidget {
  final MushafPageEntity pageData;
  final bool isDark;
  final Color textColor;
  final bool tajweedMode;
  final int fontWeight;

  const _LineBasedContent({
    required this.pageData,
    required this.isDark,
    required this.textColor,
    this.tajweedMode = false,
    this.fontWeight = 400,
  });

  // Pass 1: find the largest font size where the widest line still fits.
  // Computes global font size (Pass 1) then per-line horizontal scale factors
  // (Pass 2) to fill each line edge-to-edge — kashida-style stretching.
  static ({double fontSize, List<double> lineScales}) _computePageLayout(
    List<MushafLine> lines,
    double candidateSize,
    double maxWidth,
    FontWeight fontWeight,
    double badgeSize, // actual rendered badge width (passed from build)
  ) {
    // ── Pass 1: find font size so the widest line fits ──
    double size = candidateSize;
    for (final line in lines) {
      if (line.type == MushafLineType.surahName) continue;
      if (line.type == MushafLineType.basmala || line.isCentered) continue;
      final text = line.text.replaceAll(_ayahMarkerPattern, '');
      if (text.trim().isEmpty) continue;
      final nBadges = _ayahMarkerPattern.allMatches(line.text).length;
      final avail = maxWidth - nBadges * badgeSize;
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontFamily: _quranFont, fontSize: size, fontWeight: fontWeight, height: 1.0),
        ),
        textDirection: TextDirection.rtl,
        maxLines: 1,
      )..layout(maxWidth: double.infinity);
      if (tp.width > avail && avail > 0) {
        size = (size * avail / tp.width * 0.97).clamp(10.0, candidateSize);
      }
    }

    // ── Pass 2: per-line scaleX so text fills maxWidth ──
    final scales = <double>[];
    for (final line in lines) {
      final skip = line.type == MushafLineType.surahName ||
          line.type == MushafLineType.basmala ||
          line.isCentered;
      if (skip) { scales.add(1.0); continue; }

      final text = line.text.replaceAll(_ayahMarkerPattern, '');
      if (text.trim().isEmpty) { scales.add(1.0); continue; }

      final nBadges = _ayahMarkerPattern.allMatches(line.text).length;
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontFamily: _quranFont, fontSize: size, fontWeight: fontWeight, height: 1.0),
        ),
        textDirection: TextDirection.rtl,
        maxLines: 1,
      )..layout(maxWidth: double.infinity);

      // naturalW = text width + actual badge widths
      final naturalW = tp.width + nBadges * badgeSize;
      // scaleX stretches line to fill maxWidth; cap at 1.5 for very short lines
      final scaleX = naturalW > 0 ? (maxWidth / naturalW).clamp(1.0, 1.5) : 1.0;
      scales.add(scaleX);
    }

    return (fontSize: size, lineScales: scales);
  }

  @override
  Widget build(BuildContext context) {
    // Filter blank lines — they add white space and cause overflow
    final lines = pageData.lines!
        .where((l) => l.type == MushafLineType.surahName || l.text.trim().isNotEmpty)
        .toList();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6.w),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          // Surah name lines occupy 2.2 normal-line slots — account for this in baseLineH
          final surahNameCount = lines.where((l) => l.type == MushafLineType.surahName).length;
          final effectiveSlots = (lines.length - surahNameCount) + surahNameCount * 2.2;
          final baseLineH = constraints.maxHeight / effectiveSlots;
          final candidateSize = (baseLineH * 0.52).clamp(12.0, 22.0);
          final fw = FontWeight.values.firstWhere(
            (w) => w.value == fontWeight,
            orElse: () => FontWeight.w400,
          );
          final badgeSize = (baseLineH * 0.72).clamp(16.0, 34.0);
          final layout = _computePageLayout(lines, candidateSize, constraints.maxWidth, fw, badgeSize);
          final textFontSize = layout.fontSize;
          final lineScales = layout.lineScales;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(lines.length, (i) {
              final line = lines[i];
              final isSurahName = line.type == MushafLineType.surahName;
              final isBasmala = line.type == MushafLineType.basmala;
              final isCentered = line.isCentered || isBasmala;

              if (isSurahName) {
                return _SurahNameHeader(
                  rawText: line.text,
                  height: baseLineH * 2.2,
                  isDark: isDark,
                );
              }

              final style = TextStyle(
                fontFamily: _quranFont,
                fontSize: isBasmala ? textFontSize * 1.05 : textFontSize,
                color: textColor,
                fontWeight: isBasmala
                    ? (fw.value >= FontWeight.w500.value ? fw : FontWeight.w500)
                    : fw,
                height: 1.0,
              );

              final hasMarkers = _ayahMarkerPattern.hasMatch(line.text);

              Widget textWidget;
              if (hasMarkers) {
                textWidget = Text.rich(
                  TextSpan(
                    style: style,
                    children: _buildLineSpans(
                      text: line.text,
                      baseStyle: style,
                      badgeSize: badgeSize,
                      tajweedMode: tajweedMode,
                      isDark: isDark,
                    ),
                  ),
                  textDirection: TextDirection.rtl,
                  maxLines: 1,
                  softWrap: false,
                );
              } else if (tajweedMode) {
                textWidget = Text.rich(
                  TajweedColorizer.build(
                    text: line.text,
                    baseColor: textColor,
                    isDark: isDark,
                  ),
                  style: style,
                  textDirection: TextDirection.rtl,
                  maxLines: 1,
                  softWrap: false,
                );
              } else {
                textWidget = Text(
                  line.text,
                  textDirection: TextDirection.rtl,
                  maxLines: 1,
                  softWrap: false,
                  style: style,
                );
              }

              final scaleX = isCentered ? 1.0 : lineScales[i];
              return SizedBox(
                height: baseLineH,
                child: Align(
                  alignment: isCentered ? Alignment.center : Alignment.centerRight,
                  child: Transform.scale(
                    scaleX: scaleX,
                    scaleY: 1.0,
                    alignment: isCentered ? Alignment.center : Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: isCentered ? Alignment.center : Alignment.centerRight,
                      child: textWidget,
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

// ─── Ayah rosette painter (shared by both badge types) ───

class _AyahRosettePainter extends CustomPainter {
  final bool hasBookmark;
  const _AyahRosettePainter({this.hasBookmark = false});

  static const _gold      = Color(0xFFC8A84B);
  static const _goldDeep  = Color(0xFF8B6B14);
  static const _goldLight = Color(0xFFEDD570);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);

    // 8 small circles arranged in a ring → creates the classic rosette petal effect
    const petals = 8;
    final petalR  = r * 0.30;
    final orbitR  = r - petalR * 0.62;
    final petalPaint = Paint()..color = _gold..style = PaintingStyle.fill;

    for (int i = 0; i < petals; i++) {
      final angle = (i / petals) * 2 * pi - pi / 2;
      canvas.drawCircle(
        Offset(center.dx + orbitR * cos(angle), center.dy + orbitR * sin(angle)),
        petalR,
        petalPaint,
      );
    }

    // Central gradient circle covers petal gaps and provides main background
    final innerR = r * 0.65;
    final shader = const RadialGradient(
      center: Alignment(-0.25, -0.35),
      colors: [_goldLight, _gold, _goldDeep],
      stops: [0.0, 0.5, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: innerR));

    canvas.drawCircle(center, innerR, Paint()..shader = shader);

    // Subtle inner ring for depth
    canvas.drawCircle(
      center,
      innerR * 0.82,
      Paint()
        ..color = Colors.white.withAlpha(45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );

    // Bookmark: small red dot top-right
    if (hasBookmark) {
      canvas.drawCircle(
        Offset(center.dx + r * 0.60, center.dy - r * 0.60),
        r * 0.22,
        Paint()..color = const Color(0xFFE53935),
      );
    }
  }

  @override
  bool shouldRepaint(_AyahRosettePainter old) => old.hasBookmark != hasBookmark;
}

// ─── Inline ayah end badge (used inside _LineBasedContent lines) ───

class _AyahEndBadge extends StatelessWidget {
  final int number;
  final double size;
  const _AyahEndBadge({required this.number, required this.size});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 2.w),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: const _AyahRosettePainter(),
          ),
          Text(
            _toArabicNum(number),
            style: TextStyle(
              color: const Color(0xFF3D1C00),
              fontSize: size * 0.34,
              height: 1.0,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Surah name header (rendered inside _LineBasedContent) ───

class _SurahNameHeader extends StatelessWidget {
  final String rawText; // format: "SurahName  •  مكية/مدنية  •  N آية"
  final double height;
  final bool isDark;

  const _SurahNameHeader({
    required this.rawText,
    required this.height,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final parts = rawText.split('•').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final name = parts.isNotEmpty ? parts[0] : rawText;
    final meta = parts.length > 1 ? parts.sublist(1).join('  •  ') : '';

    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _SurahBannerPainter(isDark: isDark),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontFamily: 'ScheherazadeNew',
                  fontSize: (height * 0.28).clamp(14.0, 22.0),
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFD4B96A) : AppColors.primaryDark,
                ),
              ),
              if (meta.isNotEmpty) ...[
                SizedBox(height: 1.h),
                Text(
                  meta,
                  style: TextStyle(
                    fontSize: (height * 0.14).clamp(9.0, 13.0),
                    color: isDark
                        ? const Color(0xFFB89A50).withAlpha(210)
                        : AppColors.primaryDark.withAlpha(180),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Surah banner CustomPainter — decorative Islamic frame ───

class _SurahBannerPainter extends CustomPainter {
  final bool isDark;
  const _SurahBannerPainter({required this.isDark});

  static const _gold = Color(0xFFC8A84B);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Background gradient ──
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF1F3E1C), const Color(0xFF183014), const Color(0xFF1F3E1C)]
              : [const Color(0xFFF8F2DC), const Color(0xFFEDE4C2), const Color(0xFFF8F2DC)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    final stroke = Paint()
      ..color = _gold
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final strokeDim = Paint()
      ..color = _gold.withAlpha(120)
      ..strokeWidth = 0.55
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // Border line positions
    final t1 = h * 0.09; // top outer line y
    final t2 = h * 0.20; // top inner line y
    final b1 = h * 0.80; // bottom inner line y
    final b2 = h * 0.91; // bottom outer line y

    // Corner bracket horizontal extent
    final cxLen = w * 0.055;

    // ── Outer border lines (with gap for corner brackets) ──
    canvas.drawLine(Offset(cxLen, t1), Offset(w - cxLen, t1), stroke);
    canvas.drawLine(Offset(cxLen, b2), Offset(w - cxLen, b2), stroke);

    // ── Inner border lines ──
    canvas.drawLine(Offset(cxLen, t2), Offset(w - cxLen, t2), strokeDim);
    canvas.drawLine(Offset(cxLen, b1), Offset(w - cxLen, b1), strokeDim);

    // ── Corner L-brackets (top-left, top-right, bottom-left, bottom-right) ──
    final cyDrop = h * 0.28; // vertical drop of bracket

    // Top-left
    canvas.drawLine(Offset(0, t1), Offset(cxLen + 1, t1), stroke);
    canvas.drawLine(Offset(0, t1), Offset(0, t1 + cyDrop), stroke);
    // Top-right
    canvas.drawLine(Offset(w, t1), Offset(w - cxLen - 1, t1), stroke);
    canvas.drawLine(Offset(w, t1), Offset(w, t1 + cyDrop), stroke);
    // Bottom-left
    canvas.drawLine(Offset(0, b2), Offset(cxLen + 1, b2), stroke);
    canvas.drawLine(Offset(0, b2), Offset(0, b2 - cyDrop), stroke);
    // Bottom-right
    canvas.drawLine(Offset(w, b2), Offset(w - cxLen - 1, b2), stroke);
    canvas.drawLine(Offset(w, b2), Offset(w, b2 - cyDrop), stroke);

    // ── Center diamond medallion on outer border lines ──
    _drawDiamond(canvas, Offset(w / 2, t1), h * 0.09);
    _drawDiamond(canvas, Offset(w / 2, b2), h * 0.09);

    // ── Small dots between the double lines, at corners ──
    final dotPaint = Paint()
      ..color = _gold.withAlpha(170)
      ..style = PaintingStyle.fill;
    final dotX = cxLen * 0.45;
    final gapMidTop = (t1 + t2) / 2;
    final gapMidBot = (b1 + b2) / 2;
    canvas.drawCircle(Offset(dotX, gapMidTop), 1.6, dotPaint);
    canvas.drawCircle(Offset(w - dotX, gapMidTop), 1.6, dotPaint);
    canvas.drawCircle(Offset(dotX, gapMidBot), 1.6, dotPaint);
    canvas.drawCircle(Offset(w - dotX, gapMidBot), 1.6, dotPaint);
  }

  void _drawDiamond(Canvas canvas, Offset center, double halfH) {
    final halfW = halfH * 0.52;
    final path = Path()
      ..moveTo(center.dx, center.dy - halfH)
      ..lineTo(center.dx + halfW, center.dy)
      ..lineTo(center.dx, center.dy + halfH)
      ..lineTo(center.dx - halfW, center.dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = _gold.withAlpha(55)..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()..color = _gold..strokeWidth = 0.85..style = PaintingStyle.stroke..isAntiAlias = true,
    );
    // Center dot inside diamond
    canvas.drawCircle(
      center,
      halfH * 0.2,
      Paint()..color = _gold.withAlpha(200)..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _SurahBannerPainter old) => old.isDark != isDark;
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
    final h = 54.h;

    return SizedBox(
      height: h,
      child: CustomPaint(
        painter: _SurahBannerPainter(isDark: isDark),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                shortName,
                style: TextStyle(
                  fontFamily: 'ScheherazadeNew',
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFD4B96A) : AppColors.primaryDark,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                '$typeLabel  •  ${_toArabicNum(info.verseCount)} آية',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: isDark
                      ? const Color(0xFFB89A50).withAlpha(210)
                      : AppColors.primaryDark.withAlpha(180),
                ),
              ),
            ],
          ),
        ),
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
          fontFamily: _quranFont,
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
          fontFamily: _quranFont,
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
      fontFamily: _quranFont,
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
    final sz = 24.r;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(sz, sz),
            painter: _AyahRosettePainter(hasBookmark: hasBookmark),
          ),
          Text(
            _toArabicNum(number),
            style: TextStyle(
              color: Colors.white,
              fontSize: 8.sp,
              height: 1.0,
              fontWeight: FontWeight.w700,
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
                fontFamily: _quranFont,
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
            // Header
            Container(
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.menu_book_rounded, color: AppColors.goldLight, size: 20.r),
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
                    child: Icon(Icons.close, color: Colors.white.withAlpha(200), size: 20.r),
                  ),
                ],
              ),
            ),
            // Tabs
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
                      labelStyle: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
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
                          _BookmarksTab(state: state, onNavigate: navigate, isDark: isDark),
                          _JuzTab(state: state, onNavigate: navigate, isDark: isDark),
                          _SurahsTab(state: state, onNavigate: navigate, isDark: isDark),
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

  const _BookmarksTab({required this.state, required this.onNavigate, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final sorted = state.pageBookmarks.toList()..sort();
    final textPrimary = isDark ? const Color(0xFFEBD9A6) : const Color(0xFF1A0A00);
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
              style: TextStyle(color: textSec, fontSize: 13.sp, height: 1.6),
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
        // Find surah name for this page
        final cubit = context.read<MushafCubit>();
        final pageData = cubit.getPageData(page);
        final surahName = pageData != null && pageData.ayahs.isNotEmpty
            ? state.surahInfo(pageData.ayahs.first.surahId).arabicName
                .replaceAll('سُورَةُ', '').replaceAll('سُورَة', '').trim()
            : '';

        return ListTile(
          dense: true,
          onTap: () => onNavigate(page),
          leading: Icon(Icons.bookmark, color: AppColors.gold, size: 20.r),
          title: Text(
            'صفحة ${_toArabicNum(page)}',
            style: TextStyle(color: textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
          ),
          subtitle: surahName.isNotEmpty
              ? Text(surahName, style: TextStyle(color: textSec, fontSize: 12.sp, fontFamily: 'ScheherazadeNew'))
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

  const _JuzTab({required this.state, required this.onNavigate, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? const Color(0xFFEBD9A6) : const Color(0xFF1A0A00);
    final textSec = isDark ? Colors.white54 : Colors.black45;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;

    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      itemCount: 30,
      separatorBuilder: (_, _) => Divider(height: 1, color: dividerColor),
      itemBuilder: (context, i) {
        final juz = i + 1;
        final page = state.juzFirstPages[juz] ?? 1;
        final isCurrentJuz = (context.read<MushafCubit>().getPageData(state.currentPage)?.juzNumber ?? 1) == juz;

        return ListTile(
          dense: true,
          onTap: () => onNavigate(page),
          leading: Container(
            width: 32.r,
            height: 32.r,
            decoration: BoxDecoration(
              color: isCurrentJuz ? AppColors.primary : AppColors.primary.withAlpha(20),
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
              fontWeight: isCurrentJuz ? FontWeight.w700 : FontWeight.w500,
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

  const _SurahsTab({required this.state, required this.onNavigate, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? const Color(0xFFEBD9A6) : const Color(0xFF1A0A00);
    final textSec = isDark ? Colors.white54 : Colors.black45;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;

    // Surahs on the current page
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
            .replaceAll('سُورَةُ', '').replaceAll('سُورَة', '').trim();
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
                    color: isCurrentSurah ? AppColors.primary : AppColors.gold,
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
              fontWeight: isCurrentSurah ? FontWeight.w700 : FontWeight.w500,
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
