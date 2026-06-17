import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/reciter_entity.dart';

abstract class QuranAudioRepository {
  Future<Either<Failure, List<ReciterEntity>>> getReciters();
  String ayahUrl(String identifier, int surahNum, int ayahNum);
  String surahUrl(String identifier, int surahNum);
  Future<Either<Failure, String>> downloadSurah(
    String identifier,
    int surahNum, {
    void Function(double progress)? onProgress,
  });
  Future<bool> isSurahDownloaded(String identifier, int surahNum);
  Future<String?> localSurahPath(String identifier, int surahNum);
  Future<void> deleteSurahDownload(String identifier, int surahNum);
}
