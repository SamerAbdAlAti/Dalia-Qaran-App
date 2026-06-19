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
    void Function(double progress, int receivedBytes)? onProgress,
  });
  Future<bool> isSurahDownloaded(String identifier, int surahNum);
  Future<String?> localSurahPath(String identifier, int surahNum);
  Future<void> deleteSurahDownload(String identifier, int surahNum);

  // تحميل دائم لكل آية على حدة ("مقطعة") — يختلف عن الكاش المؤقت
  // المستخدم للتشغيل الفوري لآية واحدة في QuranAudioCubit.
  Future<Either<Failure, String>> downloadAyah(
      String identifier, int surahNum, int ayahNum);
  Future<bool> isAyahDownloaded(String identifier, int surahNum, int ayahNum);
  Future<String?> localAyahPath(String identifier, int surahNum, int ayahNum);
}
