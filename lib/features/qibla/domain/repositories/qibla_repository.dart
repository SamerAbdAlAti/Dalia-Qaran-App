import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/qibla_entity.dart';

abstract class QiblaRepository {
  Future<Either<Failure, QiblaEntity>> getQiblaData();
}
