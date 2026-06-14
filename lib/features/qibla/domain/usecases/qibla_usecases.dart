import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/qibla_entity.dart';
import '../repositories/qibla_repository.dart';

class GetQiblaData {
  final QiblaRepository repository;
  GetQiblaData(this.repository);
  Future<Either<Failure, QiblaEntity>> call() => repository.getQiblaData();
}
