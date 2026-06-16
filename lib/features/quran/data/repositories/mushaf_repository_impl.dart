import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/mushaf_entities.dart';
import '../../domain/repositories/mushaf_repository.dart';
import '../datasources/mushaf_local_datasource.dart';

class MushafRepositoryImpl implements MushafRepository {
  final MushafLocalDatasource datasource;

  MushafRepositoryImpl(this.datasource);

  @override
  Future<Either<Failure, MushafInitData>> initialize() async {
    try {
      await datasource.loadData();
      return Right(MushafInitData(
        surahInfos: datasource.getSurahInfos(),
        surahFirstPages: datasource.getSurahFirstPages(),
        juzFirstPages: datasource.getJuzFirstPages(),
        lastReadPage: datasource.getLastReadPage(),
        lastReadSurahName: datasource.getLastReadSurahName(),
        lastReadJuz: datasource.getLastReadJuz(),
        bookmarks: datasource.getBookmarks(),
        readPages: datasource.getReadPages(),
        pageBookmarks: datasource.getPageBookmarks(),
        tajweedMode: datasource.getTajweedMode(),
        fontWeight: datasource.getFontWeight(),
      ));
    } catch (e) {
      return Left(DatabaseFailure('فشل تحميل المصحف: $e'));
    }
  }

  @override
  Either<Failure, MushafPageEntity> getPage(int pageNumber) {
    try {
      return Right(datasource.getPage(pageNumber));
    } catch (e) {
      return Left(DatabaseFailure('فشل تحميل الصفحة: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveLastReadPage(int page) async {
    try {
      await datasource.saveLastReadPage(page);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<MushafBookmark>>> getBookmarks() async {
    try {
      return Right(datasource.getBookmarks());
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> saveBookmarks(
      List<MushafBookmark> bookmarks) async {
    try {
      await datasource.saveBookmarks(bookmarks);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Set<int>>> getReadPages() async {
    try {
      return Right(datasource.getReadPages());
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> saveReadPages(Set<int> pages) async {
    try {
      await datasource.saveReadPages(pages);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
