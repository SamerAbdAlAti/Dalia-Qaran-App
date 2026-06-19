import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/reciter_entity.dart';
import '../../domain/repositories/quran_audio_repository.dart';
import '../datasources/quran_audio_local_datasource.dart';
import '../datasources/quran_audio_remote_datasource.dart';
import '../models/reciter_model.dart';

const _surahAyahCounts = [
  7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128,
  111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73,
  54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60,
  49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12, 12, 30, 52, 52, 44,
  28, 28, 20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25, 22, 17, 19, 26, 30,
  20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5,
  4, 5, 6
];

const _keyRecitersCache = 'quran_audio_reciters_cache';

// cdn.islamic.network/audio-surah returns 403 — use quranicaudio.com instead.
// qdc/ paths use plain surah number (1.mp3); quran/ paths use 3-digit padding (001.mp3).
const _surahCdnPaths = <String, String>{
  'ar.alafasy':            'qdc/mishari_al_afasy/murattal',
  'ar.abdurrahmaansudais': 'qdc/abdurrahmaan_as_sudais/murattal',
  'ar.abdulsamad':         'qdc/abdul_baset/murattal',
  'ar.shaatree':           'qdc/abu_bakr_shatri/murattal',
  'ar.hanirifai':          'qdc/hani_ar_rifai/murattal',
  'ar.husary':             'qdc/khalil_al_husary/murattal',
  'ar.husarymujawwad':     'qdc/khalil_al_husary/murattal',
  'ar.ahmedajamy':         'quran/ahmed_ibn_3ali_al-3ajamy',
  'ar.abdullahbasfar':     'quran/abdullaah_basfar',
};

class QuranAudioRepositoryImpl implements QuranAudioRepository {
  final QuranAudioRemoteDatasource _remote;
  final QuranAudioLocalDatasource _local;
  final SharedPreferences _prefs;

  QuranAudioRepositoryImpl(this._remote, this._local, this._prefs);

  @override
  Future<Either<Failure, List<ReciterEntity>>> getReciters() async {
    try {
      final cached = _prefs.getString(_keyRecitersCache);
      if (cached != null) {
        final list = (jsonDecode(cached) as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(ReciterModel.fromJson)
            .toList();
        return Right(list);
      }
      final reciters = await _remote.fetchReciters();
      await _prefs.setString(
        _keyRecitersCache,
        jsonEncode(reciters.map((r) => r.toJson()).toList()),
      );
      return Right(reciters);
    } catch (_) {
      return Left(NetworkFailure('تعذّر تحميل قائمة القرّاء، تحقق من الاتصال بالإنترنت'));
    }
  }

  @override
  String ayahUrl(String identifier, int surahNum, int ayahNum) {
    int global = 0;
    for (int s = 1; s < surahNum; s++) {
      global += _surahAyahCounts[s - 1];
    }
    global += ayahNum;
    return 'https://cdn.islamic.network/quran/audio/128/$identifier/$global.mp3';
  }

  @override
  String surahUrl(String identifier, int surahNum) {
    final path = _surahCdnPaths[identifier];
    if (path == null) {
      // Fallback for unmapped reciters
      return 'https://cdn.islamic.network/quran/audio-surah/128/$identifier/${surahNum.toString().padLeft(3, '0')}.mp3';
    }
    if (path.startsWith('qdc/')) {
      return 'https://download.quranicaudio.com/$path/$surahNum.mp3';
    }
    return 'https://download.quranicaudio.com/$path/${surahNum.toString().padLeft(3, '0')}.mp3';
  }

  @override
  Future<Either<Failure, String>> downloadSurah(
    String identifier,
    int surahNum, {
    void Function(double progress, int receivedBytes)? onProgress,
  }) async {
    try {
      final url = surahUrl(identifier, surahNum);
      final path =
          await _local.downloadSurah(url, identifier, surahNum, onProgress: onProgress);
      return Right(path);
    } catch (_) {
      return Left(NetworkFailure('تعذّر تحميل السورة، تحقق من الاتصال بالإنترنت'));
    }
  }

  @override
  Future<bool> isSurahDownloaded(String identifier, int surahNum) =>
      _local.isSurahDownloaded(identifier, surahNum);

  @override
  Future<String?> localSurahPath(String identifier, int surahNum) =>
      _local.localPath(identifier, surahNum);

  @override
  Future<void> deleteSurahDownload(String identifier, int surahNum) =>
      _local.delete(identifier, surahNum);

  @override
  Future<Either<Failure, String>> downloadAyah(
      String identifier, int surahNum, int ayahNum) async {
    try {
      final url = ayahUrl(identifier, surahNum, ayahNum);
      final path = await _local.downloadAyah(url, identifier, surahNum, ayahNum);
      return Right(path);
    } catch (_) {
      return Left(NetworkFailure('تعذّر تحميل الآية'));
    }
  }

  @override
  Future<bool> isAyahDownloaded(String identifier, int surahNum, int ayahNum) =>
      _local.isAyahDownloaded(identifier, surahNum, ayahNum);

  @override
  Future<String?> localAyahPath(String identifier, int surahNum, int ayahNum) =>
      _local.localAyahPath(identifier, surahNum, ayahNum);
}
