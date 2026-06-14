import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/mushaf_entities.dart';

abstract class MushafRepository {
  Future<Either<Failure, MushafInitData>> initialize();
  Either<Failure, MushafPageEntity> getPage(int pageNumber);
  Future<Either<Failure, void>> saveLastReadPage(int page);

  // Bookmarks & highlights
  Future<Either<Failure, List<MushafBookmark>>> getBookmarks();
  Future<Either<Failure, void>> saveBookmarks(List<MushafBookmark> bookmarks);

  // Reading progress
  Future<Either<Failure, Set<int>>> getReadPages();
  Future<Either<Failure, void>> saveReadPages(Set<int> pages);
}
