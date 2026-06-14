import 'package:equatable/equatable.dart';

class QiblaEntity extends Equatable {
  final double qiblaDirection; // degrees clockwise from true north
  final double distanceKm;
  final double latitude;
  final double longitude;

  const QiblaEntity({
    required this.qiblaDirection,
    required this.distanceKm,
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object?> get props => [qiblaDirection, distanceKm, latitude, longitude];

  QiblaEntity copyWith({
    double? qiblaDirection,
    double? distanceKm,
    double? latitude,
    double? longitude,
  }) =>
      QiblaEntity(
        qiblaDirection: qiblaDirection ?? this.qiblaDirection,
        distanceKm: distanceKm ?? this.distanceKm,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
      );
}
