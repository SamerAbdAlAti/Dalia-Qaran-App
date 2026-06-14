import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/mushaf_entities.dart';

class MushafLocalDatasource {
  final SharedPreferences prefs;

  static const _keyLastReadPage = 'mushaf_last_read_page';
  static const _keyLastReadSurahName = 'mushaf_last_read_surah_name';
  static const _keyLastReadJuz = 'mushaf_last_read_juz';
  static const _keyBookmarks = 'mushaf_bookmarks';
  static const _keyReadPages = 'mushaf_read_pages';
  static const _keyTajweedMode = 'mushaf_tajweed_mode';

  List<List<MushafAyahEntity>>? _ayahPages;
  List<List<MushafLine>?>? _linePages; // null per-page = no line data for that page
  List<MushafSurahInfo>? _surahInfos;
  Map<int, int>? _surahFirstPages;

  MushafLocalDatasource(this.prefs);

  // ─── Load (tries quran_lines.json first, falls back to quran_pages.json) ───

  Future<void> loadData() async {
    if (_ayahPages != null) return;

    // Try the line-based format first
    final loaded = await _tryLoadLines();
    if (!loaded) await _loadPages();
  }

  /// Tries assets/quran/quran_lines.json — returns true if successful.
  /// Format: { "surahs": [...], "pages": [{ "p":1, "j":1,
  ///   "lines": [{"l":1,"t":"text","c":bool,"type":"normal|basmala|surah_name"},...],
  ///   "ayahs": [{"s":1,"a":1,"t":"text","j":1,"h":1,"sa":false},...]
  /// }]}
  Future<bool> _tryLoadLines() async {
    try {
      final jsonStr =
          await rootBundle.loadString('assets/quran/quran_lines.json');
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      _parseSurahs(data['surahs'] as List<dynamic>);

      final rawPages = data['pages'] as List<dynamic>;
      _ayahPages = [];
      _linePages = [];
      _surahFirstPages = {};

      for (int i = 0; i < rawPages.length; i++) {
        final pg = rawPages[i] as Map<String, dynamic>;

        // Ayahs
        final rawAyahs = (pg['ayahs'] as List<dynamic>?) ?? [];
        final ayahs = rawAyahs.map((a) {
          final m = a as Map<String, dynamic>;
          return MushafAyahEntity(
            surahId: _asInt(m['s']) ?? 1,
            ayahNum: _asInt(m['a']) ?? 1,
            text: _clean(m['t'] as String),
            juz: _asInt(m['j']) ?? 1,
            hizbQuarter: _asInt(m['h']) ?? 1,
            isSajda: (m['sa'] as bool?) ?? false,
          );
        }).toList();
        _ayahPages!.add(ayahs);

        // Lines
        final rawLines = pg['lines'] as List<dynamic>?;
        if (rawLines != null && rawLines.isNotEmpty) {
          _linePages!.add(rawLines
              .map((l) => MushafLine.fromJson(l as Map<String, dynamic>))
              .toList());
        } else {
          _linePages!.add(null);
        }

        // Surah first page index
        for (final ayah in ayahs) {
          if (ayah.ayahNum == 1 &&
              !_surahFirstPages!.containsKey(ayah.surahId)) {
            _surahFirstPages![ayah.surahId] = i + 1;
          }
        }
      }
      return true;
    } catch (_) {
      _ayahPages = null;
      _linePages = null;
      _surahInfos = null;
      _surahFirstPages = null;
      return false;
    }
  }

  /// Loads the original assets/quran/quran_pages.json (ayah-only format).
  Future<void> _loadPages() async {
    final jsonStr =
        await rootBundle.loadString('assets/quran/quran_pages.json');
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    _parseSurahs(data['surahs'] as List<dynamic>);

    final rawPages = data['pages'] as List<dynamic>;
    _ayahPages = [];
    _linePages = List<List<MushafLine>?>.filled(rawPages.length, null);
    _surahFirstPages = {};

    for (int i = 0; i < rawPages.length; i++) {
      final page = rawPages[i] as List<dynamic>;
      final ayahs = page.map((a) {
        final m = a as Map<String, dynamic>;
        return MushafAyahEntity(
          surahId: _asInt(m['s']) ?? 1,
          ayahNum: _asInt(m['a']) ?? 1,
          text: _clean(m['t'] as String),
          juz: _asInt(m['j']) ?? 1,
          hizbQuarter: _asInt(m['h']) ?? 1,
          isSajda: (m['sa'] as bool?) ?? false,
        );
      }).toList();
      _ayahPages!.add(ayahs);

      for (final ayah in ayahs) {
        if (ayah.ayahNum == 1 &&
            !_surahFirstPages!.containsKey(ayah.surahId)) {
          _surahFirstPages![ayah.surahId] = i + 1;
        }
      }
    }
  }

  void _parseSurahs(List<dynamic> rawSurahs) {
    _surahInfos = List.generate(rawSurahs.length, (i) {
      final s = rawSurahs[i] as Map<String, dynamic>;
      return MushafSurahInfo(
        id: i + 1,
        arabicName: _clean(s['n'] as String),
        type: (s['t'] as String).toLowerCase(),
        verseCount: _asInt(s['v']) ?? 0,
      );
    });
  }

  // ─── Pages ───

  MushafPageEntity getPage(int pageNumber) {
    final ayahs = _ayahPages![pageNumber - 1];
    final lines = _linePages?[pageNumber - 1];
    return MushafPageEntity(
      pageNumber: pageNumber,
      juzNumber: ayahs.isEmpty ? 1 : ayahs.first.juz,
      ayahs: ayahs,
      lines: lines,
    );
  }

  List<MushafSurahInfo> getSurahInfos() => _surahInfos!;
  Map<int, int> getSurahFirstPages() => _surahFirstPages!;
  MushafSurahInfo getSurahInfo(int surahId) => _surahInfos![surahId - 1];

  // ─── Last Read Page ───

  int getLastReadPage() => prefs.getInt(_keyLastReadPage) ?? 1;
  String getLastReadSurahName() =>
      prefs.getString(_keyLastReadSurahName) ?? '';
  int getLastReadJuz() => prefs.getInt(_keyLastReadJuz) ?? 1;

  Future<void> saveLastReadPage(int page) async {
    await prefs.setInt(_keyLastReadPage, page);
    if (_ayahPages != null && page >= 1 && page <= _ayahPages!.length) {
      final ayahs = _ayahPages![page - 1];
      if (ayahs.isNotEmpty && _surahInfos != null) {
        final info = _surahInfos![ayahs.first.surahId - 1];
        await prefs.setString(_keyLastReadSurahName, info.arabicName);
        await prefs.setInt(_keyLastReadJuz, ayahs.first.juz);
      }
    }
  }

  // ─── Tajweed Mode ───

  bool getTajweedMode() => prefs.getBool(_keyTajweedMode) ?? false;
  Future<void> saveTajweedMode(bool enabled) =>
      prefs.setBool(_keyTajweedMode, enabled);

  // ─── Bookmarks ───

  List<MushafBookmark> getBookmarks() {
    final raw = prefs.getString(_keyBookmarks);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => MushafBookmark.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveBookmarks(List<MushafBookmark> bookmarks) {
    final encoded = jsonEncode(bookmarks.map((b) => b.toJson()).toList());
    return prefs.setString(_keyBookmarks, encoded);
  }

  // ─── Reading Progress ───

  Set<int> getReadPages() {
    final raw = prefs.getString(_keyReadPages);
    if (raw == null || raw.isEmpty) return {};
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => e as int).toSet();
  }

  Future<void> saveReadPages(Set<int> pages) {
    return prefs.setString(_keyReadPages, jsonEncode(pages.toList()));
  }

  // ─── Helpers ───

  String _clean(String s) => s.replaceAll('﻿', '').trim();

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
