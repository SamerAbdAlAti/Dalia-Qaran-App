import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/widget_service.dart';
import '../../domain/entities/qibla_entity.dart';
import '../../domain/usecases/qibla_usecases.dart';

// ─── States ───

abstract class QiblaState extends Equatable {
  const QiblaState();
  @override
  List<Object?> get props => [];
}

class QiblaInitial extends QiblaState {
  const QiblaInitial();
}

class QiblaLoading extends QiblaState {
  const QiblaLoading();
}

class QiblaLoaded extends QiblaState {
  final QiblaEntity entity;
  final double? compassHeading; // null if compass unavailable
  final double? accuracy; // degrees, null if unavailable

  const QiblaLoaded({
    required this.entity,
    this.compassHeading,
    this.accuracy,
  });

  @override
  List<Object?> get props => [entity, compassHeading, accuracy];

  QiblaLoaded copyWith({
    QiblaEntity? entity,
    double? compassHeading,
    double? accuracy,
  }) =>
      QiblaLoaded(
        entity: entity ?? this.entity,
        compassHeading: compassHeading ?? this.compassHeading,
        accuracy: accuracy ?? this.accuracy,
      );
}

class QiblaPermissionDenied extends QiblaState {
  const QiblaPermissionDenied();
}

class QiblaError extends QiblaState {
  final String message;
  const QiblaError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── Cubit ───

class QiblaCubit extends Cubit<QiblaState> {
  final GetQiblaData getQiblaData;
  StreamSubscription<CompassEvent>? _compassSub;

  QiblaCubit(this.getQiblaData) : super(const QiblaInitial());

  Future<void> load() async {
    emit(const QiblaLoading());
    final result = await getQiblaData();
    result.fold(
      (failure) {
        if (failure.message.contains('permission_denied')) {
          emit(const QiblaPermissionDenied());
        } else {
          emit(QiblaError(failure.message));
        }
      },
      (entity) {
        emit(QiblaLoaded(entity: entity));
        _subscribeCompass(entity);
        _updateQiblaWidget(entity);
      },
    );
  }

  void _subscribeCompass(QiblaEntity entity) {
    _compassSub?.cancel();
    _compassSub = FlutterCompass.events?.listen((event) {
      if (event.heading == null) return;
      if (state is QiblaLoaded) {
        emit((state as QiblaLoaded).copyWith(
          compassHeading: event.heading,
          accuracy: event.accuracy,
        ));
      }
    });
  }

  void _updateQiblaWidget(QiblaEntity entity) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final city = prefs.getString(AppConstants.keyCityName) ?? '';
      await WidgetService.updateQiblaWidget(
        qiblaAngle: entity.qiblaDirection,
        cityName: city,
      );
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _compassSub?.cancel();
    return super.close();
  }
}
