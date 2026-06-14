import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/prayer_times_entity.dart';
import '../repositories/home_repository.dart';

class GetPrayerTimes {
  final HomeRepository repository;
  GetPrayerTimes(this.repository);
  Future<Either<Failure, PrayerTimesEntity>> call() => repository.getPrayerTimes();
}

class RefreshLocation {
  final HomeRepository repository;
  RefreshLocation(this.repository);
  Future<Either<Failure, PrayerTimesEntity>> call() => repository.refreshLocation();
}

class SetManualLocation {
  final HomeRepository repository;
  SetManualLocation(this.repository);
  Future<Either<Failure, PrayerTimesEntity>> call(
          double lat, double lng, String cityName) =>
      repository.setManualLocation(lat, lng, cityName);
}

class SetCalculationMethod {
  final HomeRepository repository;
  SetCalculationMethod(this.repository);
  Future<Either<Failure, PrayerTimesEntity>> call(
          String method, double lat, double lng) =>
      repository.setCalculationMethod(method, lat, lng);
}
