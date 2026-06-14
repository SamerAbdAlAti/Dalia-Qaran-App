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

  List<List<MushafAyahEntity>>? _pages;
  List<MushafSurahInfo>? _surahInfos;
  Map<int, int>? _surahFirstPages;

  MushafLocalDatasource(this.prefs);

  Future<void> loadData() async {
    if (_pages != null) return;

    final jsonStr =
        await rootBundle.loadString('assets/quran/quran_pages.json');
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    final rawSurahs = data['surahs'] as List<dynamic>;
    _surahInfos = List.generate(rawSurahs.length, (i) {
      final s = rawSurahs[i] as Map<String, dynamic>;
      return MushafSurahInfo(
        id: i + 1,
        arabicName: _clean(s['n'] as String),
        type: (s['t'] as String).toLowerCase(),
        verseCount: _asInt(s['v']) ?? 0,
      );
    });

    final rawPages = data['pages'] as List<dynamic>;
    _pages = rawPages.map((page) {
      return (page as List<dynamic>).map((a) {
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
    }).toList();

    _surahFirstPages = {};
    for (int i = 0; i < _pages!.length; i++) {
      for (final ayah in _pages![i]) {
        if (ayah.ayahNum == 1 &&
            !_surahFirstPages!.containsKey(ayah.surahId)) {
          _surahFirstPages![ayah.surahId] = i + 1;
        }
      }
    }
  }

  // ─── Pages ───

  MushafPageEntity getPage(int pageNumber) {
    final ayahs = _pages![pageNumber - 1];
    return MushafPageEntity(
      pageNumber: pageNumber,
      juzNumber: ayahs.isEmpty ? 1 : ayahs.first.juz,
      ayahs: ayahs,
    );
  }

  List<MushafSurahInfo> getSurahInfos() => _surahInfos!;
  Map<int, int> getSurahFirstPages() => _surahFirstPages!;
  MushafSurahInfo getSurahInfo(int surahId) => _surahInfos![surahId - 1];

  // ─── Last Read Page ───

  int getLastReadPage() => prefs.getInt(_keyLastReadPage) ?? 1;
  String getLastReadSurahName() => prefs.getString(_keyLastReadSurahName) ?? '';
  int getLastReadJuz() => prefs.getInt(_keyLastReadJuz) ?? 1;

  Future<void> saveLastReadPage(int page) async {
    await prefs.setInt(_keyLastReadPage, page);
    if (_pages != null && page >= 1 && page <= _pages!.length) {
      final ayahs = _pages![page - 1];
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
    final encoded =
        jsonEncode(bookmarks.map((b) => b.toJson()).toList());
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
