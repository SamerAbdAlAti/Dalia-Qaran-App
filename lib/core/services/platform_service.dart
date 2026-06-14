import 'package:flutter/services.dart';

class PlatformService {
  static const _channel = MethodChannel('app.daliya.quran/platform');

  static Future<bool> isBatteryOptimizationIgnored() async {
    try {
      return await _channel.invokeMethod<bool>('isBatteryOptimizationIgnored') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestBatteryOptimizationExemption() async {
    try {
      await _channel.invokeMethod('requestBatteryOptimizationExemption');
    } catch (_) {}
  }

  static Future<String?> getFileProviderUri(String filePath) async {
    try {
      return await _channel.invokeMethod<String>(
        'getFileProviderUri',
        {'filePath': filePath},
      );
    } catch (_) {
      return null;
    }
  }
}
