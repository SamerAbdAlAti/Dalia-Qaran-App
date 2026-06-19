import 'dart:async';
import 'package:flutter/services.dart';

class MediaNotificationService {
  static const _ch = MethodChannel('app.daliya.quran/platform');

  // Emits "play" | "pause" | "next" | "prev" when notification buttons are pressed
  static final _actionCtrl = StreamController<String>.broadcast();
  static Stream<String> get onAction => _actionCtrl.stream;

  // Emits surahNum when notification body is tapped
  static final _openCtrl = StreamController<int>.broadcast();
  static Stream<int> get onOpen => _openCtrl.stream;

  // Cold-start: tapped before AppShell was ready
  static int? pendingOpenSurahNum;

  static bool _initialized = false;

  static void init() {
    if (_initialized) return;
    _initialized = true;
    _ch.setMethodCallHandler((call) async {
      if (call.method != 'onMediaAction') return;
      final action = call.arguments as String? ?? '';
      if (action.startsWith('open:')) {
        final surahNum = int.tryParse(action.substring(5)) ?? 0;
        if (surahNum > 0) {
          pendingOpenSurahNum = surahNum;
          _openCtrl.add(surahNum);
        }
      } else if (action.isNotEmpty) {
        _actionCtrl.add(action);
      }
    });
  }

  static Future<void> show({
    required String surahName,
    required String subtitle,
    required bool isPlaying,
    required int surahNum,
  }) async {
    try {
      await _ch.invokeMethod('showPlayerNotification', {
        'surahName': surahName,
        'subtitle': subtitle,
        'isPlaying': isPlaying,
        'surahNum': surahNum,
      });
    } catch (_) {}
  }

  static Future<void> update({
    required String surahName,
    required String subtitle,
    required bool isPlaying,
    required int surahNum,
  }) async {
    try {
      await _ch.invokeMethod('updatePlayerState', {
        'surahName': surahName,
        'subtitle': subtitle,
        'isPlaying': isPlaying,
        'surahNum': surahNum,
      });
    } catch (_) {}
  }

  static Future<void> hide() async {
    try {
      await _ch.invokeMethod('hidePlayerNotification');
    } catch (_) {}
  }
}
