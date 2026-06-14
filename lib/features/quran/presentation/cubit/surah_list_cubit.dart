import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/last_read_entity.dart';
import '../../domain/entities/surah_entity.dart';
import '../../domain/usecases/quran_usecases.dart';

// ─── States ───

abstract class SurahListState extends Equatable {
  const SurahListState();
  @override
  List<Object?> get props => [];
}

class SurahListInitial extends SurahListState {
  const SurahListInitial();
}

class SurahListLoading extends SurahListState {
  const SurahListLoading();
}

class SurahListLoaded extends SurahListState {
  final List<SurahEntity> surahs;
  final List<SurahEntity> filtered;
  final String query;
  final LastReadEntity? lastRead;

  const SurahListLoaded({
    required this.surahs,
    required this.filtered,
    this.query = '',
    this.lastRead,
  });

  @override
  List<Object?> get props => [surahs, filtered, query, lastRead];

  SurahListLoaded copyWith({
    List<SurahEntity>? surahs,
    List<SurahEntity>? filtered,
    String? query,
    LastReadEntity? lastRead,
  }) =>
      SurahListLoaded(
        surahs: surahs ?? this.surahs,
        filtered: filtered ?? this.filtered,
        query: query ?? this.query,
        lastRead: lastRead ?? this.lastRead,
      );
}

class SurahListError extends SurahListState {
  final String message;
  const SurahListError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── Cubit ───

class SurahListCubit extends Cubit<SurahListState> {
  final GetSurahs _getSurahs;
  final GetLastRead _getLastRead;

  SurahListCubit(this._getSurahs, this._getLastRead)
      : super(const SurahListInitial());

  Future<void> load() async {
    emit(const SurahListLoading());
    (await _getSurahs()).fold(
      (f) => emit(SurahListError(f.message)),
      (surahs) {
        final lastRead = _getLastRead().fold((_) => null, (v) => v);
        emit(SurahListLoaded(
          surahs: surahs,
          filtered: surahs,
          lastRead: lastRead,
        ));
      },
    );
  }

  void search(String query) {
    final s = state;
    if (s is! SurahListLoaded) return;
    if (query.isEmpty) {
      emit(s.copyWith(filtered: s.surahs, query: query));
      return;
    }
    final q = query.toLowerCase();
    final filtered = s.surahs
        .where((su) =>
            su.name.contains(query) ||
            su.transliteration.toLowerCase().contains(q) ||
            su.id.toString() == query)
        .toList();
    emit(s.copyWith(filtered: filtered, query: query));
  }

  Future<void> refreshLastRead() async {
    final s = state;
    if (s is! SurahListLoaded) return;
    final lastRead = _getLastRead().fold((_) => null, (v) => v);
    emit(s.copyWith(lastRead: lastRead));
  }
}
