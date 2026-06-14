import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/ayah_entity.dart';
import '../entities/last_read_entity.dart';
import '../entities/surah_entity.dart';
import '../repositories/quran_repository.dart';

class GetSurahs {
  final QuranRepository repository;
  GetSurahs(this.repository);
  Future<Either<Failure, List<SurahEntity>>> call() => repository.getSurahs();
}

class GetAyahs {
  final QuranRepository repository;
  GetAyahs(this.repository);
  Future<Either<Failure, List<AyahEntity>>> call(int surahId) =>
      repository.getAyahs(surahId);
}

class SaveLastRead {
  final QuranRepository repository;
  SaveLastRead(this.repository);
  Future<Either<Failure, void>> call(
          int surahId, String surahName, int ayahId) =>
      repository.saveLastRead(surahId, surahName, ayahId);
}

class GetLastRead {
  final QuranRepository repository;
  GetLastRead(this.repository);
  Either<Failure, LastReadEntity?> call() => repository.getLastRead();
}
