import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/tafsir_entity.dart';

abstract class TafsirRepository {
  Future<Either<Failure, TafsirEntity>> getTafsir(int surahId, int ayahNum);
}
