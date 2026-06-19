import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/tafsir_entity.dart';
import '../repositories/tafsir_repository.dart';

class GetTafsir {
  final TafsirRepository repository;
  GetTafsir(this.repository);

  Future<Either<Failure, TafsirEntity>> call(int surahId, int ayahNum) =>
      repository.getTafsir(surahId, ayahNum);
}
