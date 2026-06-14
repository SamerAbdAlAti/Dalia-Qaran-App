import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/mushaf_entities.dart';
import '../repositories/mushaf_repository.dart';

class InitMushaf {
  final MushafRepository repository;
  InitMushaf(this.repository);
  Future<Either<Failure, MushafInitData>> call() => repository.initialize();
}

class GetMushafPage {
  final MushafRepository repository;
  GetMushafPage(this.repository);
  Either<Failure, MushafPageEntity> call(int pageNumber) =>
      repository.getPage(pageNumber);
}

class SaveMushafLastRead {
  final MushafRepository repository;
  SaveMushafLastRead(this.repository);
  Future<Either<Failure, void>> call(int page) =>
      repository.saveLastReadPage(page);
}

class GetMushafBookmarks {
  final MushafRepository repository;
  GetMushafBookmarks(this.repository);
  Future<Either<Failure, List<MushafBookmark>>> call() =>
      repository.getBookmarks();
}

class SaveMushafBookmarks {
  final MushafRepository repository;
  SaveMushafBookmarks(this.repository);
  Future<Either<Failure, void>> call(List<MushafBookmark> bookmarks) =>
      repository.saveBookmarks(bookmarks);
}

class GetMushafReadPages {
  final MushafRepository repository;
  GetMushafReadPages(this.repository);
  Future<Either<Failure, Set<int>>> call() => repository.getReadPages();
}

class SaveMushafReadPages {
  final MushafRepository repository;
  SaveMushafReadPages(this.repository);
  Future<Either<Failure, void>> call(Set<int> pages) =>
      repository.saveReadPages(pages);
}
