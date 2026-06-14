import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/ayah_entity.dart';
import '../../domain/entities/surah_entity.dart';
import '../cubit/surah_reader_cubit.dart';

class SurahReaderPage extends StatelessWidget {
  final SurahEntity surah;
  const SurahReaderPage({super.key, required this.surah});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              surah.name,
              style: TextStyle(
                  fontSize: 17.sp, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            Text(
              '${surah.totalVerses} آية · ${surah.type == 'meccan' ? 'مكية' : 'مدنية'}',
              style: TextStyle(fontSize: 11.sp, color: AppColors.goldLight),
            ),
          ],
        ),
        actions: [
          BlocBuilder<SurahReaderCubit, SurahReaderState>(
            buildWhen: (p, c) => false,
            builder: (context, _) => _FontSizeButton(colors: colors),
          ),
        ],
      ),
      body: BlocBuilder<SurahReaderCubit, SurahReaderState>(
        builder: (context, state) {
          if (state is SurahReaderLoading) {
            return Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (state is SurahReaderError) {
            return Center(
              child: Text(state.message,
                  style:
                      TextStyle(color: colors.textSecondary, fontSize: 14.sp)),
            );
          }
          if (state is SurahReaderLoaded) {
            return _AyahList(state: state, colors: colors);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _AyahList extends StatefulWidget {
  final SurahReaderLoaded state;
  final AppColorScheme colors;

  const _AyahList({required this.state, required this.colors});

  @override
  State<_AyahList> createState() => _AyahListState();
}

class _AyahListState extends State<_AyahList> {
  double _fontSize = 22;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLastRead());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToLastRead() {
    final lastId = widget.state.lastReadAyahId;
    if (lastId <= 1) return;
    final index = widget.state.ayahs.indexWhere((a) => a.id == lastId);
    if (index < 0) return;
    // include Basmala header (+1) and last-read banner (+1 if exists)
    final offset = (index + 1) * 80.0;
    _scrollController.animateTo(
      offset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ayahs = widget.state.ayahs;
    final lastReadId = widget.state.lastReadAyahId;
    final colors = widget.colors;
    final surahId = widget.state.surah.id;
    final showBasmala = surahId != 1 && surahId != 9;

    return Column(
      children: [
        _FontScaleBar(
          fontSize: _fontSize,
          onChanged: (v) => setState(() => _fontSize = v),
          colors: colors,
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            itemCount: ayahs.length + (showBasmala ? 1 : 0),
            itemBuilder: (context, index) {
              if (showBasmala && index == 0) {
                return _BasmalaHeader(colors: colors, fontSize: _fontSize);
              }
              final ayah = ayahs[index - (showBasmala ? 1 : 0)];
              final isLastRead = ayah.id == lastReadId && lastReadId > 1;
              return _AyahCard(
                ayah: ayah,
                fontSize: _fontSize,
                colors: colors,
                isHighlighted: isLastRead,
                onLongPress: () =>
                    context.read<SurahReaderCubit>().saveProgress(ayah.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BasmalaHeader extends StatelessWidget {
  final AppColorScheme colors;
  final double fontSize;
  const _BasmalaHeader({required this.colors, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      alignment: Alignment.center,
      child: Text(
        'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'ScheherazadeNew',
          fontSize: (fontSize + 2).sp,
          color: AppColors.gold,
          height: 2.0,
        ),
      ),
    );
  }
}

class _AyahCard extends StatelessWidget {
  final AyahEntity ayah;
  final double fontSize;
  final AppColorScheme colors;
  final bool isHighlighted;
  final VoidCallback onLongPress;

  const _AyahCard({
    required this.ayah,
    required this.fontSize,
    required this.colors,
    required this.isHighlighted,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        margin: EdgeInsets.only(bottom: 4.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: isHighlighted
              ? AppColors.gold.withAlpha(30)
              : colors.card,
          borderRadius: BorderRadius.circular(10.r),
          border: isHighlighted
              ? Border.all(color: AppColors.gold.withAlpha(100), width: 1)
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '${ayah.text} ۝${ayah.id}',
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'ScheherazadeNew',
                  fontSize: fontSize.sp,
                  color: colors.textPrimary,
                  height: 2.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FontSizeButton extends StatelessWidget {
  final AppColorScheme colors;
  const _FontSizeButton({required this.colors});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.text_fields, color: Colors.white, size: 22.r),
      onPressed: () {},
    );
  }
}

class _FontScaleBar extends StatelessWidget {
  final double fontSize;
  final ValueChanged<double> onChanged;
  final AppColorScheme colors;

  const _FontScaleBar({
    required this.fontSize,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.surface,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      child: Row(
        children: [
          Icon(Icons.text_decrease, color: colors.textSecondary, size: 18.r),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primary,
                thumbColor: AppColors.primary,
                inactiveTrackColor: colors.divider,
                trackHeight: 2.h,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7.r),
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: fontSize,
                min: 16,
                max: 36,
                divisions: 10,
                onChanged: onChanged,
              ),
            ),
          ),
          Icon(Icons.text_increase, color: colors.textSecondary, size: 18.r),
          SizedBox(width: 8.w),
          Text(
            'اضغط مطولاً لحفظ الموضع',
            style: TextStyle(
                color: colors.textSecondary,
                fontSize: 10.sp),
          ),
        ],
      ),
    );
  }
}
