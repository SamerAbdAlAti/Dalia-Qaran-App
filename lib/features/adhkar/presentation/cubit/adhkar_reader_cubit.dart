import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/zikr_entity.dart';
import '../../domain/usecases/adhkar_usecases.dart';

// ─── States ───

abstract class AdhkarReaderState extends Equatable {
  const AdhkarReaderState();
  @override
  List<Object?> get props => [];
}

class AdhkarReaderInitial extends AdhkarReaderState {
  const AdhkarReaderInitial();
}

class AdhkarReaderLoading extends AdhkarReaderState {
  const AdhkarReaderLoading();
}

class AdhkarReaderActive extends AdhkarReaderState {
  final List<ZikrEntity> adhkar;
  final int currentIndex;
  final Map<int, int> counts; // zikrId → current count
  final bool justCompleted;   // true for one emit when a zikr finishes

  const AdhkarReaderActive({
    required this.adhkar,
    required this.currentIndex,
    required this.counts,
    this.justCompleted = false,
  });

  ZikrEntity get current => adhkar[currentIndex];
  int get currentCount => counts[current.id] ?? 0;
  bool get isDone => currentCount >= current.repeatCount;
  bool get isFirst => currentIndex == 0;
  bool get isLast => currentIndex == adhkar.length - 1;
  int get completedCount => adhkar.where((z) => (counts[z.id] ?? 0) >= z.repeatCount).length;

  @override
  List<Object?> get props => [currentIndex, counts, justCompleted];

  AdhkarReaderActive copyWith({
    int? currentIndex,
    Map<int, int>? counts,
    bool? justCompleted,
  }) =>
      AdhkarReaderActive(
        adhkar: adhkar,
        currentIndex: currentIndex ?? this.currentIndex,
        counts: counts ?? this.counts,
        justCompleted: justCompleted ?? false,
      );
}

class AdhkarReaderComplete extends AdhkarReaderState {
  final List<ZikrEntity> adhkar;
  const AdhkarReaderComplete(this.adhkar);
  @override
  List<Object?> get props => [adhkar];
}

class AdhkarReaderError extends AdhkarReaderState {
  final String message;
  const AdhkarReaderError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── Cubit ───

class AdhkarReaderCubit extends Cubit<AdhkarReaderState> {
  final GetAdhkar getAdhkar;

  AdhkarReaderCubit(this.getAdhkar) : super(const AdhkarReaderInitial());

  Future<void> load(ZikrCategory category) async {
    emit(const AdhkarReaderLoading());
    final result = await getAdhkar(category);
    result.fold(
      (f) => emit(AdhkarReaderError(f.message)),
      (adhkar) => emit(AdhkarReaderActive(
        adhkar: adhkar,
        currentIndex: 0,
        counts: {},
      )),
    );
  }

  void tap() {
    final s = state;
    if (s is! AdhkarReaderActive || s.isDone) return;

    HapticFeedback.selectionClick();
    final newCount = s.currentCount + 1;
    final newCounts = {...s.counts, s.current.id: newCount};
    final justDone = newCount >= s.current.repeatCount;

    if (justDone) HapticFeedback.mediumImpact();

    emit(s.copyWith(counts: newCounts, justCompleted: justDone));
  }

  void next() {
    final s = state;
    if (s is! AdhkarReaderActive) return;

    if (s.isLast) {
      // Check if truly all done
      final allDone = s.adhkar.every(
          (z) => (s.counts[z.id] ?? 0) >= z.repeatCount);
      if (allDone) {
        HapticFeedback.heavyImpact();
        emit(AdhkarReaderComplete(s.adhkar));
        return;
      }
    }

    if (!s.isLast) {
      emit(s.copyWith(currentIndex: s.currentIndex + 1));
    }
  }

  void previous() {
    final s = state;
    if (s is! AdhkarReaderActive || s.isFirst) return;
    emit(s.copyWith(currentIndex: s.currentIndex - 1));
  }

  void goTo(int index) {
    final s = state;
    if (s is! AdhkarReaderActive) return;
    if (index < 0 || index >= s.adhkar.length) return;
    emit(s.copyWith(currentIndex: index));
  }

  void reset() {
    final s = state;
    if (s is AdhkarReaderActive) {
      emit(AdhkarReaderActive(
          adhkar: s.adhkar, currentIndex: 0, counts: {}));
    } else if (s is AdhkarReaderComplete) {
      emit(AdhkarReaderActive(
          adhkar: s.adhkar, currentIndex: 0, counts: {}));
    }
  }
}
