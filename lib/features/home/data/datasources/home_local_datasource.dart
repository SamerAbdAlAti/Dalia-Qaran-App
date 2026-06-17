import 'dart:async';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';

class HomeLocalDatasource {
  final SharedPreferences prefs;

  HomeLocalDatasource(this.prefs);

  Future<Map<String, dynamic>> getPrayerTimesData() async {
    final lat = prefs.getDouble(AppConstants.keyLatitude);
    final lng = prefs.getDouble(AppConstants.keyLongitude);

    if (lat != null && lng != null) {
      return _calculate(lat, lng);
    }

    final position = await _getCurrentPosition();
    await prefs.setDouble(AppConstants.keyLatitude, position.latitude);
    await prefs.setDouble(AppConstants.keyLongitude, position.longitude);
    return _calculate(position.latitude, position.longitude);
  }

  Future<Map<String, dynamic>> refreshLocationData() async {
    // تجاوز last known — المستخدم طلب موقعاً دقيقاً جديداً
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('تم رفض إذن الموقع');
    }

    // محاولة بدقة عالية (GPS) — 20 ثانية
    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 20));
    } catch (_) {
      // احتياطي: دقة متوسطة (شبكة) — 8 ثوانٍ
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw Exception('انتهت مهلة تحديد الموقع'),
      );
    }

    await prefs.setDouble(AppConstants.keyLatitude, position.latitude);
    await prefs.setDouble(AppConstants.keyLongitude, position.longitude);
    await prefs.remove(AppConstants.keyCityName);
    return _calculate(position.latitude, position.longitude);
  }

  Future<Map<String, dynamic>> setCalculationMethodData(
      String method, double lat, double lng) async {
    await prefs.setString(AppConstants.keyCalcMethod, method);
    return _calculate(lat, lng);
  }

  Future<Map<String, dynamic>> setManualLocation(
      double lat, double lng, String cityName) async {
    await prefs.setDouble(AppConstants.keyLatitude, lat);
    await prefs.setDouble(AppConstants.keyLongitude, lng);
    await prefs.setString(AppConstants.keyCityName, cityName);
    return _calculate(lat, lng);
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
      throw Exception('تم رفض إذن الموقع');
    }

    // 1. آخر موقع محفوظ — فوري (3s timeout لأن MIUI قد يتجمد بدونه)
    final last = await Geolocator.getLastKnownPosition()
        .timeout(const Duration(seconds: 3), onTimeout: () => null);
    if (last != null) {
      // ignore: avoid_print
      print('[Location] last known: ${last.latitude}, ${last.longitude} (accuracy: ${last.accuracy}m)');
      return last;
    }

    // 2. موقع الشبكة (WiFi/خلية) — سريع جداً
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 5));
      // ignore: avoid_print
      print('[Location] network: ${pos.latitude}, ${pos.longitude} (accuracy: ${pos.accuracy}m)');
      return pos;
    } catch (_) {}

    // 3. GPS — أبطأ، مهلة 12 ثانية
    final pos = await Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.low),
    ).timeout(
      const Duration(seconds: 12),
      onTimeout: () => throw Exception('انتهت مهلة تحديد الموقع'),
    );
    // ignore: avoid_print
    print('[Location] GPS: ${pos.latitude}, ${pos.longitude} (accuracy: ${pos.accuracy}m)');
    return pos;
  }

  CalculationParameters _paramsFor(String method) {
    switch (method) {
      case 'muslim_world_league':
        return CalculationMethod.muslim_world_league.getParameters();
      case 'karachi':
        return CalculationMethod.karachi.getParameters();
      case 'umm_al_qura':
        return CalculationMethod.umm_al_qura.getParameters();
      case 'kuwait':
        return CalculationMethod.kuwait.getParameters();
      case 'qatar':
        return CalculationMethod.qatar.getParameters();
      case 'dubai':
        return CalculationMethod.dubai.getParameters();
      case 'moon_sighting_committee':
        return CalculationMethod.moon_sighting_committee.getParameters();
      case 'egyptian':
      default:
        // Egyptian method with adjustments matching official Gaza/Palestine tables:
        // +1 Fajr → أذان ثاني (official Fajr prayer time)
        // +1 Dhuhr → standard Egyptian
        // +2 Maghrib → ihtiyat margin after sunset
        // -2 Isha → match official table algorithm
        return CalculationMethod.egyptian.getParameters()
            .withMethodAdjustments(PrayerAdjustments(
                fajr: 1, sunrise: 0, dhuhr: 1, asr: 0, maghrib: 2, isha: -2));
    }
  }

  Map<String, dynamic> _calculate(double lat, double lng) {
    final coordinates = Coordinates(lat, lng);
    final methodName = prefs.getString(AppConstants.keyCalcMethod) ?? 'egyptian';
    final params = _paramsFor(methodName);
    final times = PrayerTimes.today(coordinates, params);

    // الأذان الأول للفجر = ٣٠ دقيقة قبل وقت الفجر (الأذان الثاني)
    final fajrFirst = times.fajr.subtract(const Duration(minutes: 30));
    return {
      'fajrFirst': fajrFirst,
      'fajr': times.fajr,
      'sunrise': times.sunrise,
      'dhuhr': times.dhuhr,
      'asr': times.asr,
      'maghrib': times.maghrib,
      'isha': times.isha,
      'latitude': lat,
      'longitude': lng,
      'cityName': prefs.getString(AppConstants.keyCityName) ?? '',
    };
  }
}
