import 'package:dartz/dartz.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/tafsir_entity.dart';
import '../../domain/repositories/tafsir_repository.dart';
import '../datasources/tafsir_remote_datasource.dart';

class TafsirRepositoryImpl implements TafsirRepository {
  final TafsirRemoteDatasource _remote;
  final SharedPreferences _prefs;

  TafsirRepositoryImpl(this._remote, this._prefs);

  String _cacheKey(int surahId, int ayahNum) =>
      '${AppConstants.keyTafsirCachePrefix}${surahId}_$ayahNum';

  @override
  Future<Either<Failure, TafsirEntity>> getTafsir(
      int surahId, int ayahNum) async {
    final key = _cacheKey(surahId, ayahNum);
    final cached = _prefs.getString(key);
    if (cached != null) {
      return Right(TafsirEntity(
          surahId: surahId, ayahNum: ayahNum, text: cached));
    }
    try {
      final text = await _remote.fetchTafsir(surahId, ayahNum);
      await _prefs.setString(key, text);
      return Right(
          TafsirEntity(surahId: surahId, ayahNum: ayahNum, text: text));
    } catch (_) {
      return Left(NetworkFailure('تعذّر تحميل التفسير، تحقق من الاتصال بالإنترنت'));
    }
  }
}
