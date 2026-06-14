import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/ayah_entity.dart';
import '../../domain/entities/surah_entity.dart';
import '../../domain/usecases/quran_usecases.dart';

// ─── States ───

abstract class SurahReaderState extends Equatable {
  const SurahReaderState();
  @override
  List<Object?> get props => [];
}

class SurahReaderInitial extends SurahReaderState {
  const SurahReaderInitial();
}

class SurahReaderLoading extends SurahReaderState {
  const SurahReaderLoading();
}

class SurahReaderLoaded extends SurahReaderState {
  final SurahEntity surah;
  final List<AyahEntity> ayahs;
  final int lastReadAyahId;

  const SurahReaderLoaded({
    required this.surah,
    required this.ayahs,
    this.lastReadAyahId = 1,
  });

  @override
  List<Object?> get props => [surah, ayahs, lastReadAyahId];

  SurahReaderLoaded copyWith({
    SurahEntity? surah,
    List<AyahEntity>? ayahs,
    int? lastReadAyahId,
  }) =>
      SurahReaderLoaded(
        surah: surah ?? this.surah,
        ayahs: ayahs ?? this.ayahs,
        lastReadAyahId: lastReadAyahId ?? this.lastReadAyahId,
      );
}

class SurahReaderError extends SurahReaderState {
  final String message;
  const SurahReaderError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── Cubit ───

class SurahReaderCubit extends Cubit<SurahReaderState> {
  final GetAyahs _getAyahs;
  final SaveLastRead _saveLastRead;
  final GetLastRead _getLastRead;

  SurahReaderCubit(this._getAyahs, this._saveLastRead, this._getLastRead)
      : super(const SurahReaderInitial());

  Future<void> load(SurahEntity surah) async {
    emit(const SurahReaderLoading());
    (await _getAyahs(surah.id)).fold(
      (f) => emit(SurahReaderError(f.message)),
      (ayahs) {
        final lastRead = _getLastRead()
            .fold((_) => null, (v) => v?.surahId == surah.id ? v : null);
        emit(SurahReaderLoaded(
          surah: surah,
          ayahs: ayahs,
          lastReadAyahId: lastRead?.ayahId ?? 1,
        ));
      },
    );
  }

  Future<void> saveProgress(int ayahId) async {
    final s = state;
    if (s is! SurahReaderLoaded) return;
    await _saveLastRead(s.surah.id, s.surah.name, ayahId);
    emit(s.copyWith(lastReadAyahId: ayahId));
  }
}
