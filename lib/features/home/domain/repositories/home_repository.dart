import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/prayer_times_entity.dart';

abstract class HomeRepository {
  Future<Either<Failure, PrayerTimesEntity>> getPrayerTimes();
  Future<Either<Failure, PrayerTimesEntity>> refreshLocation();
  Future<Either<Failure, PrayerTimesEntity>> setManualLocation(
      double lat, double lng, String cityName);
  Future<Either<Failure, PrayerTimesEntity>> setCalculationMethod(
      String method, double lat, double lng);
}
