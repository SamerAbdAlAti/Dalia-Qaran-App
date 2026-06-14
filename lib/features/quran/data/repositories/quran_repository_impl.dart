import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/ayah_entity.dart';
import '../../domain/entities/last_read_entity.dart';
import '../../domain/entities/surah_entity.dart';
import '../../domain/repositories/quran_repository.dart';
import '../datasources/quran_local_datasource.dart';

class QuranRepositoryImpl implements QuranRepository {
  final QuranLocalDatasource datasource;

  QuranRepositoryImpl(this.datasource);

  @override
  Future<Either<Failure, List<SurahEntity>>> getSurahs() async {
    try {
      final models = await datasource.getSurahs();
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<AyahEntity>>> getAyahs(int surahId) async {
    try {
      final model = await datasource.getSurah(surahId);
      return Right(model.verses.map((v) => v.toEntity(surahId)).toList());
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> saveLastRead(
      int surahId, String surahName, int ayahId) async {
    try {
      await datasource.saveLastRead(surahId, surahName, ayahId);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Either<Failure, LastReadEntity?> getLastRead() {
    try {
      final data = datasource.getLastRead();
      if (data == null) return const Right(null);
      return Right(LastReadEntity(
        surahId: data['surahId'] as int,
        surahName: data['surahName'] as String,
        ayahId: data['ayahId'] as int,
      ));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
