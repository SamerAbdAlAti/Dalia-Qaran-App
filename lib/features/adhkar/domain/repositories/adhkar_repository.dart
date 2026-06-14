import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/zikr_entity.dart';

abstract class AdhkarRepository {
  Future<Either<Failure, List<ZikrEntity>>> getAdhkar(ZikrCategory category);
}
