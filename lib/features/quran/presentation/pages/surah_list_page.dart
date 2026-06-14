import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/surah_entity.dart';
import '../cubit/surah_list_cubit.dart';
import 'mushaf_viewer_page.dart';

String _arabicNum(int n) {
  const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return n.toString().split('').map((c) => d[int.parse(c)]).join();
}

class QuranPage extends StatelessWidget {
  const QuranPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => sl<SurahListCubit>()..load(),
        child: const _SurahListView(),
      );
}

class _SurahListView extends StatefulWidget {
  const _SurahListView();

  @override
  State<_SurahListView> createState() => _SurahListViewState();
}

class _SurahListViewState extends State<_SurahListView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(colors: colors),
            _SearchBar(
              controller: _searchController,
              colors: colors,
              onChanged: (q) =>
                  context.read<SurahListCubit>().search(q),
            ),
            const _MushafContinueCard(),
            Expanded(
              child: BlocBuilder<SurahListCubit, SurahListState>(
                builder: (context, state) {
                  if (state is SurahListLoading) {
                    return Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary),
                    );
                  }
                  if (state is SurahListError) {
                    return Center(
                      child: Text(state.message,
                          style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 14.sp)),
                    );
                  }
                  if (state is SurahListLoaded) {
                    return _SurahList(state: state, colors: colors);
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AppColorScheme colors;
  const _Header({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 12.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'القرآن الكريم',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'برواية حفص عن عاصم',
            style: TextStyle(
              color: AppColors.goldLight,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final AppColorScheme colors;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.controller,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: 14.sp, color: colors.textPrimary),
        decoration: InputDecoration(
          hintText: 'ابحث عن سورة...',
          hintStyle:
              TextStyle(color: colors.textSecondary, fontSize: 14.sp),
          prefixIcon:
              Icon(Icons.search, color: colors.textSecondary, size: 20.r),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close,
                      color: colors.textSecondary, size: 18.r),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        ),
      ),
    );
  }
}

class _SurahList extends StatelessWidget {
  final SurahListLoaded state;
  final AppColorScheme colors;

  const _SurahList({required this.state, required this.colors});

  @override
  Widget build(BuildContext context) {
    final hasLastRead = state.lastRead != null;
    final extraItems = hasLastRead ? 1 : 0;

    return ListView.builder(
      padding: EdgeInsets.only(bottom: 16.h),
      itemCount: state.filtered.length + extraItems,
      itemBuilder: (context, index) {
        if (hasLastRead && index == 0) {
          return _LastReadBanner(
            lastRead: state.lastRead!,
            colors: colors,
            allSurahs: state.surahs,
            onTap: () => _openSurah(
              context,
              state.surahs.firstWhere(
                  (s) => s.id == state.lastRead!.surahId),
            ),
          );
        }
        final surah = state.filtered[index - extraItems];
        return _SurahTile(
          surah: surah,
          colors: colors,
          onTap: () => _openSurah(context, surah),
        );
      },
    );
  }

  void _openSurah(BuildContext context, SurahEntity surah) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MushafViewerPage(surahId: surah.id),
    ));
  }
}

// ─── Mushaf Continue Reading Card ───

class _MushafContinueCard extends StatefulWidget {
  const _MushafContinueCard();

  @override
  State<_MushafContinueCard> createState() => _MushafContinueCardState();
}

class _MushafContinueCardState extends State<_MushafContinueCard> {
  int _lastPage = 0;
  String _surahName = '';
  int _juz = 1;
  int _readCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final prefs = sl<SharedPreferences>();
    final rawPages = prefs.getString('mushaf_read_pages') ?? '[]';
    int count = 0;
    try {
      count = (jsonDecode(rawPages) as List<dynamic>).length;
    } catch (_) {}
    setState(() {
      _lastPage = prefs.getInt('mushaf_last_read_page') ?? 0;
      _surahName = prefs.getString('mushaf_last_read_surah_name') ?? '';
      _juz = prefs.getInt('mushaf_last_read_juz') ?? 1;
      _readCount = count;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_lastPage <= 1) return const SizedBox.shrink();

    final colors = context.colors;
    final progress = (_readCount / 604.0).clamp(0.0, 1.0);
    final shortName = _surahName
        .replaceAll('سُورَةُ', '')
        .replaceAll('سُورَة', '')
        .trim();
    final displayName =
        shortName.isNotEmpty ? shortName : 'صفحة ${_arabicNum(_lastPage)}';

    return GestureDetector(
      onTap: () {
        Navigator.of(context)
            .push(MaterialPageRoute(
              builder: (_) => MushafViewerPage(initialPage: _lastPage),
            ))
            .then((_) => _load()); // refresh on return
      },
      child: Container(
        margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
        padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 10.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              AppColors.primary.withAlpha(22),
              AppColors.primaryDark.withAlpha(35),
            ],
          ),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: AppColors.primary.withAlpha(55),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha(12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38.r,
                  height: 38.r,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(22),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.primary,
                    size: 20.r,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'أكمل قراءة المصحف',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11.sp,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        displayName,
                        style: TextStyle(
                          fontFamily: 'ScheherazadeNew',
                          color: colors.textPrimary,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'تابع',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(Icons.arrow_back_ios,
                          color: Colors.white, size: 10.r),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Text(
                  'صفحة ${_arabicNum(_lastPage)} · الجزء ${_arabicNum(_juz)}',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11.sp,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}٪',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 5.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(3.r),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.primary.withAlpha(20),
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 4.h,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Last Read Banner (text-based reader) ───

class _LastReadBanner extends StatelessWidget {
  final dynamic lastRead;
  final AppColorScheme colors;
  final List<SurahEntity> allSurahs;
  final VoidCallback onTap;

  const _LastReadBanner({
    required this.lastRead,
    required this.colors,
    required this.allSurahs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 8.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              AppColors.primary.withAlpha(30),
              AppColors.gold.withAlpha(20),
            ],
          ),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: AppColors.gold.withAlpha(80),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36.r,
              height: 36.r,
              decoration: BoxDecoration(
                color: AppColors.gold.withAlpha(40),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bookmark,
                  color: AppColors.gold, size: 18.r),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'آخر قراءة',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11.sp,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '${lastRead.surahName} — آية ${lastRead.ayahId}',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_back_ios,
                color: colors.textSecondary, size: 14.r),
          ],
        ),
      ),
    );
  }
}

class _SurahTile extends StatelessWidget {
  final SurahEntity surah;
  final AppColorScheme colors;
  final VoidCallback onTap;

  const _SurahTile({
    required this.surah,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: colors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            _SurahNumber(number: surah.id, colors: colors),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    surah.name,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '${surah.transliteration} · ${surah.totalVerses} آية · ${_typeLabel(surah.type)}',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11.sp,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              surah.name,
              style: TextStyle(
                fontFamily: 'ScheherazadeNew',
                color: AppColors.primary,
                fontSize: 18.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String type) =>
      type == 'meccan' ? 'مكية' : 'مدنية';
}

class _SurahNumber extends StatelessWidget {
  final int number;
  final AppColorScheme colors;

  const _SurahNumber({required this.number, required this.colors});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40.r,
      height: 40.r,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.star_outline_rounded,
            color: AppColors.gold,
            size: 40.r,
          ),
          Text(
            '$number',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
