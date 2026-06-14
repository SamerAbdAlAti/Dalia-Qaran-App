import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/zikr_entity.dart';
import '../repositories/adhkar_repository.dart';

class GetAdhkar {
  final AdhkarRepository repository;
  GetAdhkar(this.repository);
  Future<Either<Failure, List<ZikrEntity>>> call(ZikrCategory category) =>
      repository.getAdhkar(category);
}
