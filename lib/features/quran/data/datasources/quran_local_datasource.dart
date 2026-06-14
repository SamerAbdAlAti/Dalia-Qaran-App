import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/surah_model.dart';

class QuranLocalDatasource {
  final SharedPreferences prefs;
  List<SurahModel>? _cachedSurahs;

  QuranLocalDatasource(this.prefs);

  Future<List<SurahModel>> getSurahs() async {
    if (_cachedSurahs != null) return _cachedSurahs!;
    final json = await rootBundle.loadString('assets/quran/hafs.json');
    final list = jsonDecode(json) as List<dynamic>;
    _cachedSurahs = list
        .map((e) => SurahModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cachedSurahs!;
  }

  Future<SurahModel> getSurah(int surahId) async {
    final surahs = await getSurahs();
    return surahs.firstWhere((s) => s.id == surahId);
  }

  Future<void> saveLastRead(int surahId, String surahName, int ayahId) async {
    await prefs.setInt(AppConstants.keyLastReadSurah, surahId);
    await prefs.setString(AppConstants.keyLastReadSurahName, surahName);
    await prefs.setInt(AppConstants.keyLastReadAyah, ayahId);
  }

  Map<String, dynamic>? getLastRead() {
    final surahId = prefs.getInt(AppConstants.keyLastReadSurah);
    if (surahId == null) return null;
    return {
      'surahId': surahId,
      'surahName': prefs.getString(AppConstants.keyLastReadSurahName) ?? '',
      'ayahId': prefs.getInt(AppConstants.keyLastReadAyah) ?? 1,
    };
  }
}
