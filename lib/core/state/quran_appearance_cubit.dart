import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

// ─── Quran page color theme (text + page background) ───

enum QuranColorTheme { classic, sepia, green, night }

extension QuranColorThemeX on QuranColorTheme {
  String get label => switch (this) {
        QuranColorTheme.classic => 'كلاسيكي',
        QuranColorTheme.sepia => 'بُني',
        QuranColorTheme.green => 'أخضر',
        QuranColorTheme.night => 'ليلي',
      };

  Color get textColor => switch (this) {
        QuranColorTheme.classic => const Color(0xFF1A0A00),
        QuranColorTheme.sepia => const Color(0xFF3E2412),
        QuranColorTheme.green => const Color(0xFF14391F),
        QuranColorTheme.night => const Color(0xFFEBD9A6),
      };

  Color get pageBackground => switch (this) {
        QuranColorTheme.classic => const Color(0xFFFBF6E8),
        QuranColorTheme.sepia => const Color(0xFFF1E4C9),
        QuranColorTheme.green => const Color(0xFFEAF3EC),
        QuranColorTheme.night => const Color(0xFF1C1509),
      };
}

// ─── Recitation (playing-ayah) highlight color ───

enum RecitationHighlightColor { gold, green, blue, pink }

extension RecitationHighlightColorX on RecitationHighlightColor {
  String get label => switch (this) {
        RecitationHighlightColor.gold => 'ذهبي',
        RecitationHighlightColor.green => 'أخضر',
        RecitationHighlightColor.blue => 'أزرق',
        RecitationHighlightColor.pink => 'وردي',
      };

  Color get color => switch (this) {
        RecitationHighlightColor.gold => const Color(0xFFFFF176),
        RecitationHighlightColor.green => const Color(0xFFA5D6A7),
        RecitationHighlightColor.blue => const Color(0xFF90CAF9),
        RecitationHighlightColor.pink => const Color(0xFFF48FB1),
      };
}

// ─── States ───

class QuranAppearanceState {
  final QuranColorTheme colorTheme;
  final RecitationHighlightColor highlightColor;
  const QuranAppearanceState({
    required this.colorTheme,
    required this.highlightColor,
  });
}

// ─── Cubit ───

class QuranAppearanceCubit extends Cubit<QuranAppearanceState> {
  final SharedPreferences _prefs;

  QuranAppearanceCubit(this._prefs) : super(_load(_prefs));

  static QuranAppearanceState _load(SharedPreferences prefs) {
    final themeName = prefs.getString(AppConstants.keyQuranColorTheme);
    final highlightName = prefs.getString(AppConstants.keyQuranHighlightColor);
    return QuranAppearanceState(
      colorTheme: QuranColorTheme.values.firstWhere(
        (e) => e.name == themeName,
        orElse: () => QuranColorTheme.classic,
      ),
      highlightColor: RecitationHighlightColor.values.firstWhere(
        (e) => e.name == highlightName,
        orElse: () => RecitationHighlightColor.gold,
      ),
    );
  }

  void setColorTheme(QuranColorTheme theme) {
    _prefs.setString(AppConstants.keyQuranColorTheme, theme.name);
    emit(QuranAppearanceState(
      colorTheme: theme,
      highlightColor: state.highlightColor,
    ));
  }

  void setHighlightColor(RecitationHighlightColor color) {
    _prefs.setString(AppConstants.keyQuranHighlightColor, color.name);
    emit(QuranAppearanceState(
      colorTheme: state.colorTheme,
      highlightColor: color,
    ));
  }
}
