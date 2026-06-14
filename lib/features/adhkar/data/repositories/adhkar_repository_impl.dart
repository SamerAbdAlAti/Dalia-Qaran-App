import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/zikr_entity.dart';
import '../../domain/repositories/adhkar_repository.dart';
import '../datasources/adhkar_datasource.dart';

class AdhkarRepositoryImpl implements AdhkarRepository {
  final AdhkarDatasource datasource;
  AdhkarRepositoryImpl(this.datasource);

  @override
  Future<Either<Failure, List<ZikrEntity>>> getAdhkar(
      ZikrCategory category) async {
    try {
      return Right(datasource.getAdhkar(category));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
