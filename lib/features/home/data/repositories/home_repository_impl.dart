import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/prayer_times_entity.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/home_local_datasource.dart';

class HomeRepositoryImpl implements HomeRepository {
  final HomeLocalDatasource datasource;

  HomeRepositoryImpl(this.datasource);

  @override
  Future<Either<Failure, PrayerTimesEntity>> getPrayerTimes() async {
    try {
      return Right(_map(await datasource.getPrayerTimesData()));
    } catch (e) {
      return Left(LocationFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, PrayerTimesEntity>> refreshLocation() async {
    try {
      return Right(_map(await datasource.refreshLocationData()));
    } catch (e) {
      return Left(LocationFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, PrayerTimesEntity>> setManualLocation(
      double lat, double lng, String cityName) async {
    try {
      return Right(_map(await datasource.setManualLocation(lat, lng, cityName)));
    } catch (e) {
      return Left(LocationFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, PrayerTimesEntity>> setCalculationMethod(
      String method, double lat, double lng) async {
    try {
      return Right(
          _map(await datasource.setCalculationMethodData(method, lat, lng)));
    } catch (e) {
      return Left(LocationFailure(e.toString()));
    }
  }

  PrayerTimesEntity _map(Map<String, dynamic> d) => PrayerTimesEntity(
        fajrFirst: d['fajrFirst'] as DateTime,
        fajr: d['fajr'] as DateTime,
        sunrise: d['sunrise'] as DateTime,
        dhuhr: d['dhuhr'] as DateTime,
        asr: d['asr'] as DateTime,
        maghrib: d['maghrib'] as DateTime,
        isha: d['isha'] as DateTime,
        latitude: d['latitude'] as double,
        longitude: d['longitude'] as double,
        cityName: d['cityName'] as String,
      );
}
