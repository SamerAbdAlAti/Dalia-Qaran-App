import 'dart:async';
import 'dart:io';
import 'package:adhan/adhan.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz_local;
import 'package:workmanager/workmanager.dart';
import '../constants/app_constants.dart';
import 'notification_service.dart';
import 'widget_service.dart';

const _kDailyRescheduleTask = 'daliya_daily_reschedule';
const _kDownloadReciterTask  = 'daliya_download_reciter';
const _kWidgetRefreshTask    = 'daliya_widget_refresh';

// CDN paths — mirrors quran_audio_repository_impl.dart
const _bgCdnPaths = <String, String>{
  'ar.alafasy':            'qdc/mishari_al_afasy/murattal',
  'ar.abdurrahmaansudais': 'qdc/abdurrahmaan_as_sudais/murattal',
  'ar.abdulsamad':         'qdc/abdul_baset/murattal',
  'ar.shaatree':           'qdc/abu_bakr_shatri/murattal',
  'ar.hanirifai':          'qdc/hani_ar_rifai/murattal',
  'ar.husary':             'qdc/khalil_al_husary/murattal',
  'ar.husarymujawwad':     'qdc/khalil_al_husary/murattal',
  'ar.ahmedajamy':         'quran/ahmed_ibn_3ali_al-3ajamy',
  'ar.abdullahbasfar':     'quran/abdullaah_basfar',
};

const _bgSurahNames = [
  'الفاتحة', 'البقرة', 'آل عمران', 'النساء', 'المائدة',
  'الأنعام', 'الأعراف', 'الأنفال', 'التوبة', 'يونس',
  'هود', 'يوسف', 'الرعد', 'إبراهيم', 'الحجر',
  'النحل', 'الإسراء', 'الكهف', 'مريم', 'طه',
  'الأنبياء', 'الحج', 'المؤمنون', 'النور', 'الفرقان',
  'الشعراء', 'النمل', 'القصص', 'العنكبوت', 'الروم',
  'لقمان', 'السجدة', 'الأحزاب', 'سبأ', 'فاطر',
  'يس', 'الصافات', 'ص', 'الزمر', 'غافر',
  'فصلت', 'الشورى', 'الزخرف', 'الدخان', 'الجاثية',
  'الأحقاف', 'محمد', 'الفتح', 'الحجرات', 'ق',
  'الذاريات', 'الطور', 'النجم', 'القمر', 'الرحمن',
  'الواقعة', 'الحديد', 'المجادلة', 'الحشر', 'الممتحنة',
  'الصف', 'الجمعة', 'المنافقون', 'التغابن', 'الطلاق',
  'التحريم', 'الملك', 'القلم', 'الحاقة', 'المعارج',
  'نوح', 'الجن', 'المزمل', 'المدثر', 'القيامة',
  'الإنسان', 'المرسلات', 'النبأ', 'النازعات', 'عبس',
  'التكوير', 'الانفطار', 'المطففين', 'الانشقاق', 'البروج',
  'الطارق', 'الأعلى', 'الغاشية', 'الفجر', 'البلد',
  'الشمس', 'الليل', 'الضحى', 'الشرح', 'التين',
  'العلق', 'القدر', 'البينة', 'الزلزلة', 'العاديات',
  'القارعة', 'التكاثر', 'العصر', 'الهمزة', 'الفيل',
  'قريش', 'الماعون', 'الكوثر', 'الكافرون', 'النصر',
  'المسد', 'الإخلاص', 'الفلق', 'الناس',
];

String _bgSurahUrl(String identifier, int surahNum) {
  final path = _bgCdnPaths[identifier];
  if (path == null) {
    return 'https://cdn.islamic.network/quran/audio-surah/128/$identifier/${surahNum.toString().padLeft(3, '0')}.mp3';
  }
  if (path.startsWith('qdc/')) {
    return 'https://download.quranicaudio.com/$path/$surahNum.mp3';
  }
  return 'https://download.quranicaudio.com/$path/${surahNum.toString().padLeft(3, '0')}.mp3';
}

Future<bool> _bgIsSurahDownloaded(String identifier, int surahNum) async {
  final appDir = await getApplicationDocumentsDirectory();
  final fileName = '${surahNum.toString().padLeft(3, '0')}.mp3';
  final file = File('${appDir.path}/quran_audio/$identifier/$fileName');
  return file.existsSync() && file.lengthSync() > 0;
}

Future<void> _bgDownloadSurah(
  String identifier,
  int surahNum, {
  void Function(int received, int total)? onProgress,
}) async {
  final url = _bgSurahUrl(identifier, surahNum);
  final appDir = await getApplicationDocumentsDirectory();
  final audioDir = Directory('${appDir.path}/quran_audio/$identifier');
  if (!await audioDir.exists()) await audioDir.create(recursive: true);
  final fileName  = surahNum.toString().padLeft(3, '0');
  final finalFile = File('${audioDir.path}/$fileName.mp3');
  final tempFile  = File('${audioDir.path}/$fileName.tmp');

  final resumeFrom = tempFile.existsSync() ? tempFile.lengthSync() : 0;

  final request = http.Request('GET', Uri.parse(url));
  request.headers['User-Agent'] = 'Daliya/1.0 (Android; Quran App)';
  request.headers['Accept'] = 'audio/mpeg, audio/*, */*';
  if (resumeFrom > 0) request.headers['Range'] = 'bytes=$resumeFrom-';

  final response = await request.send().timeout(const Duration(seconds: 60));

  if (response.statusCode == 416) {
    await response.stream.drain<void>();
    if (tempFile.existsSync()) await tempFile.delete();
    throw Exception('HTTP 416 — سيُعاد التحميل من البداية');
  }
  if (response.statusCode != 200 && response.statusCode != 206) {
    await response.stream.drain<void>();
    throw Exception('HTTP ${response.statusCode}');
  }

  // Parse total size for progress reporting
  int totalBytes = 0;
  int receivedBytes = resumeFrom;
  if (response.statusCode == 206) {
    final cr = response.headers['content-range'] ?? '';
    final slash = cr.lastIndexOf('/');
    if (slash != -1) totalBytes = int.tryParse(cr.substring(slash + 1)) ?? 0;
  } else {
    totalBytes = int.tryParse(response.headers['content-length'] ?? '') ?? 0;
  }

  final writeMode = response.statusCode == 206 ? FileMode.append : FileMode.write;
  final sink = tempFile.openWrite(mode: writeMode);
  try {
    await Future(() async {
      await for (final chunk in response.stream.timeout(const Duration(seconds: 60))) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        onProgress?.call(receivedBytes, totalBytes);
      }
    }).timeout(const Duration(minutes: 8));
    await sink.flush();
    await sink.close();
    if (await finalFile.exists()) await finalFile.delete();
    await tempFile.rename(finalFile.path);
  } catch (e) {
    await sink.flush();
    await sink.close();
    rethrow;
  }
}

/// يُستدعى من WorkManager في isolate منفصل — يعيد جدولة الصلوات يومياً
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    // ─── تحميل القرآن الصوتي في الخلفية ───
    if (taskName == _kDownloadReciterTask) {
      final identifier = inputData?['identifier'] as String?;
      final arabicName = inputData?['arabicName'] as String?;
      if (identifier == null || arabicName == null) return true;
      try {
        // ignore: avoid_print
        print('[BG-Download] starting: $identifier');
        await NotificationService.init();
        // ignore: avoid_print
        print('[BG-Download] NotificationService.init done');
        const total = 114;
        final List<int> failed = [];
        for (int surahNum = 1; surahNum <= total; surahNum++) {
          if (await _bgIsSurahDownloaded(identifier, surahNum)) continue;
          final surahName = surahNum <= _bgSurahNames.length
              ? _bgSurahNames[surahNum - 1]
              : '';
          // ignore: avoid_print
          print('[BG-Download] downloading surah $surahNum ($surahName)');
          // Speed + throttle state (reset per surah)
          var lastNotifMs    = 0;
          var lastSpeedBytes = 0;
          var lastSpeedMs    = DateTime.now().millisecondsSinceEpoch;
          var speedKBps      = 0.0;

          await NotificationService.showDownloadProgress(
            reciterName: arabicName,
            surahNum: surahNum,
            total: total,
            surahName: surahName,
          );
          bool ok = false;
          for (int attempt = 0; attempt < 3 && !ok; attempt++) {
            if (attempt > 0) await Future.delayed(const Duration(seconds: 5));
            try {
              await _bgDownloadSurah(
                identifier,
                surahNum,
                onProgress: (received, bytesTotal) {
                  final now = DateTime.now().millisecondsSinceEpoch;
                  // Recalculate speed every 2s
                  final deltaMs = now - lastSpeedMs;
                  if (deltaMs >= 2000) {
                    speedKBps = (received - lastSpeedBytes) * 1000.0 / (deltaMs * 1024.0);
                    lastSpeedBytes = received;
                    lastSpeedMs = now;
                  }
                  // Throttle: at most one notification update per 800ms
                  if (now - lastNotifMs >= 800) {
                    lastNotifMs = now;
                    final pct = bytesTotal > 0
                        ? ((received / bytesTotal) * 100).round()
                        : 0;
                    unawaited(NotificationService.showDownloadProgress(
                      reciterName: arabicName,
                      surahNum: surahNum,
                      total: total,
                      surahName: surahName,
                      surahPercent: pct,
                      speedKBps: speedKBps,
                    ));
                  }
                },
              );
              ok = true;
            } catch (e) {
              // ignore: avoid_print
              print('[BG-Download] surah $surahNum attempt ${attempt + 1} failed: $e');
            }
          }
          if (!ok) {
            // ignore: avoid_print
            print('[BG-Download] skipping surah $surahNum after 3 attempts');
            failed.add(surahNum);
          }
        }
        await NotificationService.cancelDownloadNotification();
        if (failed.isEmpty) {
          await NotificationService.showDownloadComplete(reciterName: arabicName);
          // ignore: avoid_print
          print('[BG-Download] complete: $identifier');
        } else {
          await NotificationService.showDownloadComplete(
            reciterName: arabicName,
            failedCount: failed.length,
          );
          // ignore: avoid_print
          print('[BG-Download] done with ${failed.length} skipped: $identifier — $failed');
        }
      } catch (e) {
        // ignore: avoid_print
        print('[BG-Download] fatal error: $e');
      }
      return true;
    }

    // ─── تحديث App Widgets دورياً بدون فتح التطبيق ───
    // onUpdate() الأصلي في AppWidgetProvider لا يعيد الحساب — فقط يعيد رسم
    // آخر صورة محفوظة. لذلك التحديث الفعلي للبيانات (الصلاة القادمة، القبلة،
    // آية اليوم) يحتاج هذه المهمة الدورية لإعادة الحساب وتوليد صورة جديدة.
    if (taskName == _kWidgetRefreshTask) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final lat = prefs.getDouble(AppConstants.keyLatitude);
        final lng = prefs.getDouble(AppConstants.keyLongitude);
        if (lat == null || lng == null) return true;

        final prayerMap = _calcPrayers(lat, lng, prefs, DateTime.now());
        final now = DateTime.now();
        final upcoming = prayerMap.entries
            .where((e) => e.value.isAfter(now))
            .toList()
          ..sort((a, b) => a.value.compareTo(b.value));
        final next = upcoming.isNotEmpty ? upcoming.first : prayerMap.entries.last;
        final minutesLeft = next.value.difference(now).inMinutes.clamp(0, 9999);

        await WidgetService.updatePrayerWidget(
          prayerTimes: prayerMap,
          nextPrayer: next.key,
          nextPrayerTime: next.value,
          minutesLeft: minutesLeft,
        );

        final qibla = Qibla(Coordinates(lat, lng));
        final cityName = prefs.getString(AppConstants.keyCityName) ?? '';
        await WidgetService.updateQiblaWidget(
          qiblaAngle: qibla.direction,
          cityName: cityName,
        );

        await WidgetService.updateTodayAyah();
      } catch (_) {}
      return true;
    }

    // ─── إعادة جدولة الصلوات يومياً ───
    if (taskName != _kDailyRescheduleTask) return true;
    try {
      tz.initializeTimeZones();
      try {
        final tzName = await FlutterTimezone.getLocalTimezone();
        tz_local.setLocalLocation(tz_local.getLocation(tzName));
      } catch (_) {}
      await NotificationService.init();

      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(AppConstants.keyLatitude);
      final lng = prefs.getDouble(AppConstants.keyLongitude);
      if (lat == null || lng == null) return true;

      final times = _calcPrayers(lat, lng, prefs, DateTime.now());

      final soundId = prefs.getString(AppConstants.keyNotifSound) ?? 'default';
      final reminderMin = prefs.getInt(AppConstants.keyNotifReminderMin) ?? 0;
      final vibrate = prefs.getBool(AppConstants.keyNotifVibrate) ?? true;
      final customSoundUri = prefs.getString(AppConstants.keyCustomSoundUri);
      final offset = ReminderOffset.values.firstWhere(
        (r) => r.minutes == reminderMin,
        orElse: () => ReminderOffset.none,
      );

      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowTimes = _calcPrayers(lat, lng, prefs, tomorrow);

      await NotificationService.scheduleAllPrayers(
        prayerTimes: times,
        tomorrowPrayerTimes: tomorrowTimes,
        enabledPrayers: {
          'الفجر': prefs.getBool(AppConstants.keyNotifyFajr) ?? true,
          'الظهر': prefs.getBool(AppConstants.keyNotifyDhuhr) ?? true,
          'العصر': prefs.getBool(AppConstants.keyNotifyAsr) ?? true,
          'المغرب': prefs.getBool(AppConstants.keyNotifyMaghrib) ?? true,
          'العشاء': prefs.getBool(AppConstants.keyNotifyIsha) ?? true,
        },
        soundId: soundId,
        offset: offset,
        vibrate: vibrate,
        customSoundUri: customSoundUri,
      );
    } catch (_) {}
    return true;
  });
}

Map<String, DateTime> _calcPrayers(
    double lat, double lng, SharedPreferences prefs, [DateTime? date]) {
  final coords = Coordinates(lat, lng);
  final method = prefs.getString(AppConstants.keyCalcMethod) ?? 'egyptian';
  final params = _paramsFor(method);
  final PrayerTimes times;
  if (date == null) {
    times = PrayerTimes.today(coords, params);
  } else {
    times = PrayerTimes(coords, DateComponents(date.year, date.month, date.day), params);
  }
  return {
    'الفجر': times.fajr,
    'الظهر': times.dhuhr,
    'العصر': times.asr,
    'المغرب': times.maghrib,
    'العشاء': times.isha,
  };
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
    default:
      return CalculationMethod.egyptian.getParameters().withMethodAdjustments(
            PrayerAdjustments(
                fajr: 1, sunrise: 0, dhuhr: 1, asr: 0, maghrib: 2, isha: -2),
          );
  }
}

class BackgroundService {
  static Future<void> init() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  static Future<void> scheduleDailyReschedule() async {
    await Workmanager().registerPeriodicTask(
      _kDailyRescheduleTask,
      _kDailyRescheduleTask,
      frequency: const Duration(hours: 24),
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: false,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }

  static Future<void> scheduleWidgetRefresh() async {
    // الحد الأدنى المسموح لـ WorkManager الدورية هو ١٥ دقيقة؛ نستخدم ٣٠ دقيقة
    // مطابقة لـ updatePeriodMillis في ملفات XML الخاصة بالـ widgets.
    await Workmanager().registerPeriodicTask(
      _kWidgetRefreshTask,
      _kWidgetRefreshTask,
      frequency: const Duration(minutes: 30),
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: false,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }

  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
  }

  static Future<void> startReciterDownload(
      String identifier, String arabicName) async {
    await Workmanager().registerOneOffTask(
      'download_reciter_$identifier',
      _kDownloadReciterTask,
      inputData: {'identifier': identifier, 'arabicName': arabicName},
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  static Future<void> cancelReciterDownload(String identifier) async {
    await Workmanager().cancelByUniqueName('download_reciter_$identifier');
  }
}
