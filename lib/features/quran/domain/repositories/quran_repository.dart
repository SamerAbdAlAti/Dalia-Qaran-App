import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/ayah_entity.dart';
import '../entities/last_read_entity.dart';
import '../entities/surah_entity.dart';

abstract class QuranRepository {
  Future<Either<Failure, List<SurahEntity>>> getSurahs();
  Future<Either<Failure, List<AyahEntity>>> getAyahs(int surahId);
  Future<Either<Failure, void>> saveLastRead(
      int surahId, String surahName, int ayahId);
  Either<Failure, LastReadEntity?> getLastRead();
}
