import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/mushaf_entities.dart';
import '../../domain/usecases/mushaf_usecases.dart';

// ─── States ───

abstract class MushafState {}

class MushafInitial extends MushafState {}

class MushafLoading extends MushafState {}

class MushafReady extends MushafState {
  final int currentPage;
  final List<MushafSurahInfo> surahInfos;
  final Map<int, int> surahFirstPages;
  final Map<int, int> juzFirstPages;
  final List<MushafBookmark> bookmarks;
  final Set<int> readPages;
  final Set<int> pageBookmarks;
  final bool tajweedMode;
  final int fontWeight;

  MushafReady({
    required this.currentPage,
    required this.surahInfos,
    required this.surahFirstPages,
    this.juzFirstPages = const {},
    this.bookmarks = const [],
    this.readPages = const {},
    this.pageBookmarks = const {},
    this.tajweedMode = false,
    this.fontWeight = 400,
  });

  MushafReady copyWith({
    int? currentPage,
    List<MushafBookmark>? bookmarks,
    Set<int>? readPages,
    Set<int>? pageBookmarks,
    bool? tajweedMode,
    int? fontWeight,
  }) =>
      MushafReady(
        currentPage: currentPage ?? this.currentPage,
        surahInfos: surahInfos,
        surahFirstPages: surahFirstPages,
        juzFirstPages: juzFirstPages,
        bookmarks: bookmarks ?? this.bookmarks,
        readPages: readPages ?? this.readPages,
        pageBookmarks: pageBookmarks ?? this.pageBookmarks,
        tajweedMode: tajweedMode ?? this.tajweedMode,
        fontWeight: fontWeight ?? this.fontWeight,
      );

  MushafSurahInfo surahInfo(int surahId) => surahInfos[surahId - 1];

  MushafBookmark? bookmarkFor(int surahId, int ayahNum) {
    for (final b in bookmarks) {
      if (b.surahId == surahId && b.ayahNum == ayahNum) return b;
    }
    return null;
  }

  double get readingProgress => readPages.length / 604.0;
  int get readPagesCount => readPages.length;
}

class MushafError extends MushafState {
  final String message;
  MushafError(this.message);
}

// ─── Cubit ───

class MushafCubit extends Cubit<MushafState> {
  final InitMushaf _initMushaf;
  final GetMushafPage _getMushafPage;
  final SaveMushafLastRead _saveLastRead;
  final SaveMushafBookmarks _saveBookmarks;
  final SaveMushafReadPages _saveReadPages;
  final SharedPreferences _prefs;

  static const _keyTajweedMode = 'mushaf_tajweed_mode';
  static const _keyFontWeight = 'mushaf_font_weight';

  MushafCubit(
    this._initMushaf,
    this._getMushafPage,
    this._saveLastRead,
    this._saveBookmarks,
    this._saveReadPages,
    this._prefs,
  ) : super(MushafInitial());

  Future<void> initialize({int? startPage}) async {
    emit(MushafLoading());
    final result = await _initMushaf();
    result.fold(
      (f) => emit(MushafError(f.message)),
      (data) => emit(MushafReady(
        currentPage: startPage ?? data.lastReadPage,
        surahInfos: data.surahInfos,
        surahFirstPages: data.surahFirstPages,
        juzFirstPages: data.juzFirstPages,
        bookmarks: data.bookmarks,
        readPages: data.readPages,
        pageBookmarks: data.pageBookmarks,
        tajweedMode: data.tajweedMode,
        fontWeight: data.fontWeight,
      )),
    );
  }

  void setPage(int page) {
    if (state is! MushafReady) return;
    final s = state as MushafReady;
    final newReadPages = {...s.readPages, page};
    _saveLastRead(page);
    _saveReadPages(newReadPages);
    emit(s.copyWith(currentPage: page, readPages: newReadPages));
  }

  MushafPageEntity? getPageData(int pageNumber) {
    final result = _getMushafPage(pageNumber);
    return result.fold((_) => null, (page) => page);
  }

  int getFirstPageForSurah(int surahId) {
    if (state is MushafReady) {
      return (state as MushafReady).surahFirstPages[surahId] ?? 1;
    }
    return 1;
  }

  void toggleTajweed() {
    if (state is! MushafReady) return;
    final s = state as MushafReady;
    final newMode = !s.tajweedMode;
    _prefs.setBool(_keyTajweedMode, newMode);
    emit(s.copyWith(tajweedMode: newMode));
  }

  void setFontWeight(int weight) {
    if (state is! MushafReady) return;
    final s = state as MushafReady;
    _prefs.setInt(_keyFontWeight, weight);
    emit(s.copyWith(fontWeight: weight));
  }

  void togglePageBookmark(int page) {
    if (state is! MushafReady) return;
    final s = state as MushafReady;
    final updated = Set<int>.from(s.pageBookmarks);
    if (updated.contains(page)) {
      updated.remove(page);
    } else {
      updated.add(page);
    }
    _prefs.setString('mushaf_page_bookmarks', jsonEncode(updated.toList()));
    emit(s.copyWith(pageBookmarks: updated));
  }

  // ─── Bookmarks ───

  void addOrUpdateBookmark(MushafBookmark bookmark) {
    if (state is! MushafReady) return;
    final s = state as MushafReady;
    final updated = [
      for (final b in s.bookmarks)
        if (b.surahId == bookmark.surahId && b.ayahNum == bookmark.ayahNum)
          bookmark
        else
          b,
    ];
    if (!updated.any(
        (b) => b.surahId == bookmark.surahId && b.ayahNum == bookmark.ayahNum)) {
      updated.add(bookmark);
    }
    _saveBookmarks(updated);
    emit(s.copyWith(bookmarks: updated));
  }

  void removeBookmark(int surahId, int ayahNum) {
    if (state is! MushafReady) return;
    final s = state as MushafReady;
    final updated = s.bookmarks
        .where((b) => !(b.surahId == surahId && b.ayahNum == ayahNum))
        .toList();
    _saveBookmarks(updated);
    emit(s.copyWith(bookmarks: updated));
  }
}
