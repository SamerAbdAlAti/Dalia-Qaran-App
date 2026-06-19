import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';

class QiblaLocalDatasource {
  final SharedPreferences prefs;

  static const double _meccaLat = 21.4225;
  static const double _meccaLng = 39.8262;

  QiblaLocalDatasource(this.prefs);

  Future<Map<String, double>> getQiblaData() async {
    final savedLat = prefs.getDouble(AppConstants.keyLatitude);
    final savedLng = prefs.getDouble(AppConstants.keyLongitude);

    final double latitude;
    final double longitude;

    if (savedLat != null && savedLng != null) {
      latitude = savedLat;
      longitude = savedLng;
    } else {
      throw Exception('no_location_saved');
    }

    final coordinates = Coordinates(latitude, longitude);
    final qibla = Qibla(coordinates);
    final distanceMeters = Geolocator.distanceBetween(
      latitude,
      longitude,
      _meccaLat,
      _meccaLng,
    );

    return {
      'qiblaDirection': qibla.direction,
      'distanceKm': distanceMeters / 1000,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  Future<Position> _getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('خدمة الموقع معطلة');

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('permission_denied');
    }

    final last = await Geolocator.getLastKnownPosition();
    if (last != null) return last;

    // GPS فقط — LocationAccuracy.medium يعتمد غالباً على الشبكة/الخلية
    // ولا يعمل بدون إنترنت.
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('انتهت مهلة GPS — تأكد أن GPS مفعّل وحاول في مكان مكشوف'),
    );
  }
}
