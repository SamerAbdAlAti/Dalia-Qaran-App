import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/reciter_entity.dart';
import '../repositories/quran_audio_repository.dart';

class GetReciters {
  final QuranAudioRepository repository;
  GetReciters(this.repository);
  Future<Either<Failure, List<ReciterEntity>>> call() => repository.getReciters();
}

class DownloadSurah {
  final QuranAudioRepository repository;
  DownloadSurah(this.repository);
  Future<Either<Failure, String>> call(
    String identifier,
    int surahNum, {
    void Function(double progress, int receivedBytes)? onProgress,
  }) =>
      repository.downloadSurah(identifier, surahNum, onProgress: onProgress);
}
