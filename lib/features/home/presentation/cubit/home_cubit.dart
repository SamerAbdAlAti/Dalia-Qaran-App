import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/prayer_timer_service.dart';
import '../../../../core/services/reminders_service.dart';
import '../../../../core/services/widget_service.dart';
import '../../domain/entities/prayer_times_entity.dart';
import '../../domain/usecases/home_usecases.dart';

// ─── States ───

abstract class HomeState extends Equatable {
  const HomeState();
  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {
  const HomeInitial();
}

class HomeLoading extends HomeState {
  const HomeLoading();
}

class HomeLoaded extends HomeState {
  final PrayerTimesEntity prayerTimes;
  final DateTime now;

  const HomeLoaded({required this.prayerTimes, required this.now});

  @override
  List<Object?> get props => [prayerTimes, now];

  HomeLoaded copyWith({PrayerTimesEntity? prayerTimes, DateTime? now}) =>
      HomeLoaded(
        prayerTimes: prayerTimes ?? this.prayerTimes,
        now: now ?? this.now,
      );
}

class HomeLocationDisabled extends HomeState {
  const HomeLocationDisabled();
}

class HomeError extends HomeState {
  final String message;
  const HomeError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── Cubit ───

class HomeCubit extends Cubit<HomeState> {
  final GetPrayerTimes _getPrayerTimes;
  final RefreshLocation _refreshLocation;
  final SetManualLocation _setManualLocation;
  final SetCalculationMethod _setCalculationMethod;
  Timer? _timer;

  HomeCubit(this._getPrayerTimes, this._refreshLocation,
      this._setManualLocation, this._setCalculationMethod)
      : super(const HomeInitial());

  Future<void> load() async {
    emit(const HomeLoading());
    (await _getPrayerTimes()).fold(
      (f) => emit(_classifyFailure(f.message)),
      (times) {
        _startTimer();
        emit(HomeLoaded(prayerTimes: times, now: DateTime.now()));
        _scheduleNotifications(times);
        _scheduleReminders(times);
        _updateWidgets(times);
        Future.delayed(
          const Duration(seconds: 1),
          NotificationService.requestPermission,
        );
      },
    );
  }

  Future<void> refresh() async {
    (await _refreshLocation()).fold(
      (f) => emit(_classifyFailure(f.message)),
      (times) {
        emit(HomeLoaded(prayerTimes: times, now: DateTime.now()));
        _scheduleNotifications(times);
        _scheduleReminders(times);
        _updateWidgets(times);
      },
    );
  }

  Future<void> setCity(double lat, double lng, String cityName) async {
    emit(const HomeLoading());
    (await _setManualLocation(lat, lng, cityName)).fold(
      (f) => emit(HomeError(f.message)),
      (times) {
        _startTimer();
        emit(HomeLoaded(prayerTimes: times, now: DateTime.now()));
        _scheduleNotifications(times);
        _scheduleReminders(times);
        _updateWidgets(times);
      },
    );
  }

  Future<void> changeCalculationMethod(String method) async {
    final s = state;
    if (s is! HomeLoaded) return;
    (await _setCalculationMethod(
            method, s.prayerTimes.latitude, s.prayerTimes.longitude))
        .fold(
      (f) => emit(HomeError(f.message)),
      (times) {
        emit(s.copyWith(prayerTimes: times));
        _scheduleNotifications(times);
        _scheduleReminders(times);
        _updateWidgets(times);
      },
    );
  }

  void _scheduleReminders(PrayerTimesEntity times) {
    try {
      final prefs = sl<SharedPreferences>();
      RemindersService.scheduleAll(
        prefs: {
          AppConstants.keyReminderAdhkarMorning:     prefs.getBool(AppConstants.keyReminderAdhkarMorning) ?? false,
          AppConstants.keyReminderAdhkarMorningTime: prefs.getString(AppConstants.keyReminderAdhkarMorningTime) ?? '06:00',
          AppConstants.keyReminderAdhkarEvening:     prefs.getBool(AppConstants.keyReminderAdhkarEvening) ?? false,
          AppConstants.keyReminderAdhkarEveningTime: prefs.getString(AppConstants.keyReminderAdhkarEveningTime) ?? '16:00',
          AppConstants.keyReminderFajrSunnah:        prefs.getBool(AppConstants.keyReminderFajrSunnah) ?? false,
          AppConstants.keyReminderFajrSunnahMin:     prefs.getInt(AppConstants.keyReminderFajrSunnahMin) ?? 20,
          AppConstants.keyReminderQiyam:              prefs.getBool(AppConstants.keyReminderQiyam) ?? false,
          AppConstants.keyReminderDuha:              prefs.getBool(AppConstants.keyReminderDuha) ?? false,
          AppConstants.keyReminderDuhaTime:          prefs.getString(AppConstants.keyReminderDuhaTime) ?? '09:00',
          AppConstants.keyReminderQuran:             prefs.getBool(AppConstants.keyReminderQuran) ?? false,
          AppConstants.keyReminderQuranTime:         prefs.getString(AppConstants.keyReminderQuranTime) ?? '20:00',
          AppConstants.keyReminderSalahAnnabi:       prefs.getBool(AppConstants.keyReminderSalahAnnabi) ?? false,
          AppConstants.keyReminderSalahAnnabiTime:   prefs.getString(AppConstants.keyReminderSalahAnnabiTime) ?? '12:00',
        },
        fajrTime: times.fajr,
        ishaTime: times.isha,
      );
      RemindersService.scheduleDhikrAll(
        prefs: {
          AppConstants.keyDhikrIstighfar:         prefs.getBool(AppConstants.keyDhikrIstighfar) ?? false,
          AppConstants.keyDhikrIstighfarInterval: prefs.getInt(AppConstants.keyDhikrIstighfarInterval) ?? 60,
          AppConstants.keyDhikrIstighfarSound:    prefs.getString(AppConstants.keyDhikrIstighfarSound) ?? 'dhikr_istighfar',
          AppConstants.keyDhikrSalawat:           prefs.getBool(AppConstants.keyDhikrSalawat) ?? false,
          AppConstants.keyDhikrSalawatInterval:   prefs.getInt(AppConstants.keyDhikrSalawatInterval) ?? 60,
          AppConstants.keyDhikrSalawatSound:      prefs.getString(AppConstants.keyDhikrSalawatSound) ?? 'dhikr_salawat',
          AppConstants.keyDhikrTasbih:            prefs.getBool(AppConstants.keyDhikrTasbih) ?? false,
          AppConstants.keyDhikrTasbihInterval:    prefs.getInt(AppConstants.keyDhikrTasbihInterval) ?? 60,
          AppConstants.keyDhikrTasbihSound:       prefs.getString(AppConstants.keyDhikrTasbihSound) ?? 'dhikr_tasbih',
          AppConstants.keyDhikrPostPrayer:        prefs.getBool(AppConstants.keyDhikrPostPrayer) ?? false,
        },
      );
    } catch (_) {}
  }

  void _updateWidgets(PrayerTimesEntity times) {
    try {
      final prayerMap = {
        'الفجر': times.fajr,
        'الظهر': times.dhuhr,
        'العصر': times.asr,
        'المغرب': times.maghrib,
        'العشاء': times.isha,
      };
      final now = DateTime.now();
      final upcoming = prayerMap.entries
          .where((e) => e.value.isAfter(now))
          .toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      final next = upcoming.isNotEmpty ? upcoming.first : prayerMap.entries.last;
      final minutesLeft = next.value.difference(now).inMinutes.clamp(0, 9999);
      WidgetService.updatePrayerWidget(
        prayerTimes: prayerMap,
        nextPrayer: next.key,
        nextPrayerTime: next.value,
        minutesLeft: minutesLeft,
      );
    } catch (_) {}
  }

  void _scheduleNotifications(PrayerTimesEntity times) {
    try {
      final prefs = sl<SharedPreferences>();
      final soundId = prefs.getString(AppConstants.keyNotifSound) ?? 'default';
      final reminderMin = prefs.getInt(AppConstants.keyNotifReminderMin) ?? 0;
      final vibrate = prefs.getBool(AppConstants.keyNotifVibrate) ?? true;
      final customSoundUri = prefs.getString(AppConstants.keyCustomSoundUri);
      final offset = ReminderOffset.values.firstWhere(
        (r) => r.minutes == reminderMin,
        orElse: () => ReminderOffset.none,
      );
      final prayerMap = {
        'الفجر': times.fajr,
        'الظهر': times.dhuhr,
        'العصر': times.asr,
        'المغرب': times.maghrib,
        'العشاء': times.isha,
      };
      final enabledMap = {
        'الفجر': prefs.getBool(AppConstants.keyNotifyFajr) ?? true,
        'الظهر': prefs.getBool(AppConstants.keyNotifyDhuhr) ?? true,
        'العصر': prefs.getBool(AppConstants.keyNotifyAsr) ?? true,
        'المغرب': prefs.getBool(AppConstants.keyNotifyMaghrib) ?? true,
        'العشاء': prefs.getBool(AppConstants.keyNotifyIsha) ?? true,
      };

      // Dart timers — يعمل عندما يكون محرك Flutter حياً (تطبيق مفتوح أو في الخلفية)
      PrayerTimerService.scheduleToday(
        prayerTimes: prayerMap,
        enabledPrayers: enabledMap,
        soundId: soundId,
        vibrate: vibrate,
        reminderMinutes: reminderMin,
        customSoundUri: customSoundUri,
      );

      // AlarmManager — backup لعند إغلاق التطبيق كلياً (يحتاج Autostart على MIUI)
      NotificationService.scheduleAllPrayers(
        prayerTimes: prayerMap,
        enabledPrayers: enabledMap,
        soundId: soundId,
        offset: offset,
        vibrate: vibrate,
        customSoundUri: customSoundUri,
      );
    } catch (_) {}
  }

  HomeState _classifyFailure(String message) {
    if (message.contains('معطلة') || message.contains('Location services')) {
      return const HomeLocationDisabled();
    }
    return HomeError(message);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      final s = state;
      if (s is HomeLoaded) emit(s.copyWith(now: DateTime.now()));
    });
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
