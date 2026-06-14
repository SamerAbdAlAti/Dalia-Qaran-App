import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
      },
    );
  }

  Future<void> refresh() async {
    (await _refreshLocation()).fold(
      (f) => emit(_classifyFailure(f.message)),
      (times) => emit(HomeLoaded(prayerTimes: times, now: DateTime.now())),
    );
  }

  Future<void> setCity(double lat, double lng, String cityName) async {
    emit(const HomeLoading());
    (await _setManualLocation(lat, lng, cityName)).fold(
      (f) => emit(HomeError(f.message)),
      (times) {
        _startTimer();
        emit(HomeLoaded(prayerTimes: times, now: DateTime.now()));
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
      (times) => emit(s.copyWith(prayerTimes: times)),
    );
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
