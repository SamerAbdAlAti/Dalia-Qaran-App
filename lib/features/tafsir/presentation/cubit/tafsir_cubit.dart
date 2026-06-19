import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/tafsir_usecases.dart';

// ─── States ───

abstract class TafsirState {}

class TafsirInitial extends TafsirState {}

class TafsirLoading extends TafsirState {}

class TafsirLoaded extends TafsirState {
  final String text;
  TafsirLoaded(this.text);
}

class TafsirError extends TafsirState {
  final String message;
  TafsirError(this.message);
}

// ─── Cubit ───

class TafsirCubit extends Cubit<TafsirState> {
  final GetTafsir _getTafsir;

  TafsirCubit(this._getTafsir) : super(TafsirInitial());

  Future<void> load(int surahId, int ayahNum) async {
    emit(TafsirLoading());
    final result = await _getTafsir(surahId, ayahNum);
    if (isClosed) return;
    result.fold(
      (f) => emit(TafsirError(f.message)),
      (entity) => emit(TafsirLoaded(entity.text)),
    );
  }
}
