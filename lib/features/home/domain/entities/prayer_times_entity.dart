import 'package:equatable/equatable.dart';

class PrayerTimesEntity extends Equatable {
  final DateTime fajrFirst;   // الأذان الأول — ٣٠ دقيقة قبل الفجر
  final DateTime fajr;        // الأذان الثاني — وقت صلاة الفجر الفعلي
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;
  final double latitude;
  final double longitude;
  final String cityName;

  const PrayerTimesEntity({
    required this.fajrFirst,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.latitude,
    required this.longitude,
    this.cityName = '',
  });

  @override
  List<Object?> get props => [
        fajrFirst, fajr, sunrise, dhuhr, asr, maghrib, isha,
        latitude, longitude, cityName,
      ];

  PrayerTimesEntity copyWith({
    DateTime? fajrFirst,
    DateTime? fajr,
    DateTime? sunrise,
    DateTime? dhuhr,
    DateTime? asr,
    DateTime? maghrib,
    DateTime? isha,
    double? latitude,
    double? longitude,
    String? cityName,
  }) =>
      PrayerTimesEntity(
        fajrFirst: fajrFirst ?? this.fajrFirst,
        fajr: fajr ?? this.fajr,
        sunrise: sunrise ?? this.sunrise,
        dhuhr: dhuhr ?? this.dhuhr,
        asr: asr ?? this.asr,
        maghrib: maghrib ?? this.maghrib,
        isha: isha ?? this.isha,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        cityName: cityName ?? this.cityName,
      );
}
