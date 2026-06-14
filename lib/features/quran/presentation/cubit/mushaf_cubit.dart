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
  final List<MushafBookmark> bookmarks;
  final Set<int> readPages;
  final bool tajweedMode;

  MushafReady({
    required this.currentPage,
    required this.surahInfos,
    required this.surahFirstPages,
    this.bookmarks = const [],
    this.readPages = const {},
    this.tajweedMode = false,
  });

  MushafReady copyWith({
    int? currentPage,
    List<MushafBookmark>? bookmarks,
    Set<int>? readPages,
    bool? tajweedMode,
  }) =>
      MushafReady(
        currentPage: currentPage ?? this.currentPage,
        surahInfos: surahInfos,
        surahFirstPages: surahFirstPages,
        bookmarks: bookmarks ?? this.bookmarks,
        readPages: readPages ?? this.readPages,
        tajweedMode: tajweedMode ?? this.tajweedMode,
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
        bookmarks: data.bookmarks,
        readPages: data.readPages,
        tajweedMode: data.tajweedMode,
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
