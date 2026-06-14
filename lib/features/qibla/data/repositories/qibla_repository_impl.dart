import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/qibla_entity.dart';
import '../../domain/repositories/qibla_repository.dart';
import '../datasources/qibla_local_datasource.dart';

class QiblaRepositoryImpl implements QiblaRepository {
  final QiblaLocalDatasource datasource;

  QiblaRepositoryImpl(this.datasource);

  @override
  Future<Either<Failure, QiblaEntity>> getQiblaData() async {
    try {
      final data = await datasource.getQiblaData();
      return Right(QiblaEntity(
        qiblaDirection: data['qiblaDirection']!,
        distanceKm: data['distanceKm']!,
        latitude: data['latitude']!,
        longitude: data['longitude']!,
      ));
    } catch (e) {
      return Left(LocationFailure(e.toString()));
    }
  }
}
