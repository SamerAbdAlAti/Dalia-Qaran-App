import 'package:flutter/material.dart';

/// Programmatic tajweed coloring based on Arabic Unicode diacritic rules.
/// Works on any Uthmanic/Hafs Quran text without an external data file.
class TajweedColorizer {
  // ─── Light mode colors ───
  static const _cMadd = Color(0xFF1565C0);      // blue  – مد
  static const _cQalqala = Color(0xFF6A1B9A);   // purple – قلقلة
  static const _cGhunna = Color(0xFF1B5E20);    // dark green – غنة/إدغام
  static const _cIkhfaa = Color(0xFFBF360C);    // deep orange – إخفاء

  // ─── Dark mode colors (lighter) ───
  static const _cMaddD = Color(0xFF64B5F6);
  static const _cQalqalaD = Color(0xFFCE93D8);
  static const _cGhunnaD = Color(0xFF81C784);
  static const _cIkhfaaD = Color(0xFFFF8A65);

  // ─── Letter sets ───
  // Qalqalah: ق ط ب ج د
  static const _qalqala = {0x0642, 0x0637, 0x0628, 0x062C, 0x062F};
  // Ghunna carriers: ن م
  static const _ghunna = {0x0646, 0x0645};
  // Ikhfaa letters (14): ت ث ج د ذ ز س ش ص ض ط ظ ف ق ك
  static const _ikhfaa = {
    0x062A, 0x062B, 0x062C, 0x062F, 0x0630,
    0x0632, 0x0633, 0x0634, 0x0635, 0x0636,
    0x0637, 0x0638, 0x0641, 0x0642, 0x0643
  };

  static bool _isLetter(int cp) =>
      (cp >= 0x0621 && cp <= 0x063A) ||
      (cp >= 0x0641 && cp <= 0x064A) ||
      cp == 0x0671; // alef wasla

  static bool _isDiac(int cp) => cp >= 0x064B && cp <= 0x065F;

  static Color? _classify(
      int cp, String chunk, int? nextCp, bool dark) {
    final marks = chunk.length > 1 ? chunk.substring(1) : '';

    // Maddah sign ٓ (U+0653) or آ (U+0622) → madd
    if (marks.contains('ٓ') || cp == 0x0622) {
      return dark ? _cMaddD : _cMadd;
    }

    // Bare ا (U+0627) / و (U+0648) / ي (U+064A) without any diacritic → natural madd
    if (marks.isEmpty &&
        (cp == 0x0627 || cp == 0x0648 || cp == 0x064A)) {
      return dark ? _cMaddD : _cMadd;
    }

    final hasSukun = marks.contains('ْ');
    final hasShadda = marks.contains('ّ');
    final hasTanwin = marks.contains('ً') ||
        marks.contains('ٌ') ||
        marks.contains('ٍ');

    // Qalqalah: one of (ق ط ب ج د) + sukun
    if (hasSukun && _qalqala.contains(cp)) {
      return dark ? _cQalqalaD : _cQalqala;
    }

    // Ghunna: (ن م) + shadda
    if (hasShadda && _ghunna.contains(cp)) {
      return dark ? _cGhunnaD : _cGhunna;
    }

    // Ikhfaa: ن + sukun before an ikhfaa letter
    if (hasSukun && cp == 0x0646 && nextCp != null && _ikhfaa.contains(nextCp)) {
      return dark ? _cIkhfaaD : _cIkhfaa;
    }

    // Ikhfaa: tanwin before an ikhfaa letter
    if (hasTanwin && nextCp != null && _ikhfaa.contains(nextCp)) {
      return dark ? _cIkhfaaD : _cIkhfaa;
    }

    return null;
  }

  /// Returns a [TextSpan] with tajweed-colored children.
  /// Pass [backgroundColor] to apply a highlight behind all characters.
  static TextSpan build({
    required String text,
    required Color baseColor,
    required bool isDark,
    Color? backgroundColor,
  }) {
    final segments = <(String, Color?)>[];
    int i = 0;

    while (i < text.length) {
      final cp = text.codeUnitAt(i);

      if (!_isLetter(cp)) {
        segments.add((text[i], null));
        i++;
        continue;
      }

      final start = i++;
      while (i < text.length && _isDiac(text.codeUnitAt(i))) { i++; }
      final chunk = text.substring(start, i);

      // Peek ahead for next Arabic letter (for ikhfaa cross-letter check)
      int? nextCp;
      for (int j = i; j < text.length; j++) {
        final jcp = text.codeUnitAt(j);
        if (_isLetter(jcp)) { nextCp = jcp; break; }
        if (!_isDiac(jcp) && jcp != 0x0020) break;
      }

      segments.add((chunk, _classify(cp, chunk, nextCp, isDark)));
    }

    // Merge consecutive same-color segments for fewer spans
    final children = <TextSpan>[];
    int k = 0;
    while (k < segments.length) {
      final color = segments[k].$2;
      final buf = StringBuffer(segments[k].$1);
      k++;
      while (k < segments.length && segments[k].$2 == color) {
        buf.write(segments[k].$1);
        k++;
      }
      children.add(TextSpan(
        text: buf.toString(),
        style: TextStyle(
          color: color ?? baseColor,
          backgroundColor: backgroundColor,
        ),
      ));
    }

    return TextSpan(children: children);
  }
}
