import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/background_service.dart';
import '../../domain/entities/reciter_entity.dart';
import '../../domain/repositories/quran_audio_repository.dart';
import '../../domain/usecases/quran_audio_usecases.dart';

// ─── States ───

abstract class QuranAudioState {}

class QuranAudioInitial extends QuranAudioState {}

class QuranAudioLoadingReciters extends QuranAudioState {}

class QuranAudioRecitersLoaded extends QuranAudioState {
  final List<ReciterEntity> reciters;
  final ReciterEntity? selectedReciter;

  QuranAudioRecitersLoaded({required this.reciters, this.selectedReciter});
}

class QuranAudioPlaying extends QuranAudioState {
  final ReciterEntity reciter;
  final int surahNum;
  final int? ayahNum;
  final bool isSurah;
  final Duration position;
  final Duration? duration;
  final bool isBuffering;

  QuranAudioPlaying({
    required this.reciter,
    required this.surahNum,
    this.ayahNum,
    required this.isSurah,
    this.position = Duration.zero,
    this.duration,
    this.isBuffering = false,
  });

  QuranAudioPlaying copyWith({
    Duration? position,
    Duration? duration,
    bool? isBuffering,
  }) =>
      QuranAudioPlaying(
        reciter: reciter,
        surahNum: surahNum,
        ayahNum: ayahNum,
        isSurah: isSurah,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        isBuffering: isBuffering ?? this.isBuffering,
      );
}

class QuranAudioPaused extends QuranAudioState {
  final ReciterEntity reciter;
  final int surahNum;
  final int? ayahNum;
  final bool isSurah;

  QuranAudioPaused({
    required this.reciter,
    required this.surahNum,
    this.ayahNum,
    required this.isSurah,
  });
}

class QuranAudioDownloading extends QuranAudioState {
  final ReciterEntity reciter;
  final int surahNum;
  final double progress;

  QuranAudioDownloading({
    required this.reciter,
    required this.surahNum,
    required this.progress,
  });
}

class QuranAudioError extends QuranAudioState {
  final String message;
  QuranAudioError(this.message);
}

// ─── Cubit ───

const _keySelectedReciter = 'quran_audio_selected_reciter';

class QuranAudioCubit extends Cubit<QuranAudioState> {
  final GetReciters _getReciters;
  final DownloadSurah _downloadSurah;
  final QuranAudioRepository _repository;
  final SharedPreferences _prefs;

  final AudioPlayer _player = AudioPlayer();

  List<ReciterEntity> _reciters = [];
  ReciterEntity? _selectedReciter;

  // Public getters so widgets can read reciters without waiting for RecitersLoaded state
  List<ReciterEntity> get reciters => List.unmodifiable(_reciters);
  ReciterEntity? get selectedReciter => _selectedReciter;

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;

  QuranAudioCubit(
    this._getReciters,
    this._downloadSurah,
    this._repository,
    this._prefs,
  ) : super(QuranAudioInitial()) {
    _initStreams();
  }

  Future<void> _initStreams() async {
    await _player.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.gain,
        stayAwake: true,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: const {},
      ),
    ));
    _playerStateSub = _player.onPlayerStateChanged.listen(_onPlayerState);
    _positionSub = _player.onPositionChanged.listen(_onPosition);
    _durationSub = _player.onDurationChanged.listen(_onDuration);
  }

  void _onPlayerState(PlayerState ps) {
    final s = state;
    if (ps == PlayerState.completed) {
      if (s is QuranAudioPlaying) {
        emit(QuranAudioRecitersLoaded(
          reciters: _reciters,
          selectedReciter: _selectedReciter,
        ));
      }
    }
  }

  void _onPosition(Duration pos) {
    final s = state;
    if (s is QuranAudioPlaying) {
      emit(s.copyWith(position: pos, isBuffering: false));
    }
  }

  void _onDuration(Duration dur) {
    final s = state;
    if (s is QuranAudioPlaying) {
      emit(s.copyWith(duration: dur));
    }
  }

  Future<void> loadReciters() async {
    emit(QuranAudioLoadingReciters());
    final result = await _getReciters();
    result.fold(
      (f) => emit(QuranAudioError(f.message)),
      (reciters) {
        _reciters = reciters;
        final savedId = _prefs.getString(_keySelectedReciter);
        // Validate saved reciter — if it's not in the versebyverse list (e.g. it was
        // selected from a surah-only context), reset to the first valid reciter.
        _selectedReciter = savedId != null
            ? reciters.where((r) => r.identifier == savedId).firstOrNull
            : null;
        _selectedReciter ??= reciters.isNotEmpty ? reciters.first : null;
        if (_selectedReciter != null) {
          _prefs.setString(_keySelectedReciter, _selectedReciter!.identifier);
        }
        emit(QuranAudioRecitersLoaded(
          reciters: _reciters,
          selectedReciter: _selectedReciter,
        ));
      },
    );
  }

  void selectReciter(ReciterEntity r) {
    _selectedReciter = r;
    _prefs.setString(_keySelectedReciter, r.identifier);
    emit(QuranAudioRecitersLoaded(
      reciters: _reciters,
      selectedReciter: _selectedReciter,
    ));
  }

  Future<void> playAyah(int surahNum, int ayahNum) async {
    final reciter = _selectedReciter;
    if (reciter == null) {
      await loadReciters();
      return;
    }
    await _player.stop();
    final url = _repository.ayahUrl(reciter.identifier, surahNum, ayahNum);
    emit(QuranAudioPlaying(
      reciter: reciter,
      surahNum: surahNum,
      ayahNum: ayahNum,
      isSurah: false,
      isBuffering: true,
    ));
    // CDN doesn't support HTTP Range requests → Android MediaPlayer fails with error (1, -2147483648).
    // Download to temp file first so we play from a seekable local source.
    final localPath = await _cacheAyah(reciter.identifier, surahNum, ayahNum, url);
    if (isClosed) return;
    if (localPath == null || localPath.startsWith('__error_')) {
      final code = localPath?.replaceFirst('__error_', '') ?? '?';
      // 403/404 → this reciter doesn't have per-ayah audio on the CDN.
      // Fall back to playing the full surah so the user isn't left with silence.
      if (code == '403' || code == '404') {
        emit(QuranAudioError(
            'هذا القارئ لا يدعم تشغيل الآية المفردة — سيتم تشغيل السورة كاملة'));
        await Future.delayed(const Duration(seconds: 2));
        if (!isClosed) await playSurah(surahNum);
        return;
      }
      emit(QuranAudioError('تعذّر تحميل الآية، تحقق من الاتصال بالإنترنت'));
      return;
    }
    await _player.setSourceDeviceFile(localPath);
    await _player.resume();
    // Pre-fetch next ayah so it plays instantly (fire-and-forget)
    unawaited(_cacheAyah(
      reciter.identifier,
      surahNum,
      ayahNum + 1,
      _repository.ayahUrl(reciter.identifier, surahNum, ayahNum + 1),
    ));
  }

  Future<String?> _cacheAyah(
      String identifier, int surahNum, int ayahNum, String url) async {
    try {
      final dir = await getTemporaryDirectory();
      final file =
          File('${dir.path}/ayah_${identifier}_${surahNum}_$ayahNum.mp3');
      if (await file.exists() && await file.length() > 0) return file.path;
      final res = await http.get(Uri.parse(url), headers: const {
        'User-Agent': 'Daliya/1.0 (Android; Quran App)',
        'Accept': 'audio/mpeg, */*',
      }).timeout(const Duration(seconds: 30));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        await file.writeAsBytes(res.bodyBytes);
        return file.path;
      }
      // Return status code so caller can emit a specific error
      return '__error_${res.statusCode}';
    } catch (_) {}
    return null;
  }

  Future<void> playSurah(int surahNum) async {
    final reciter = _selectedReciter;
    if (reciter == null) {
      await loadReciters();
      return;
    }
    await _player.stop();

    String? localPath =
        await _repository.localSurahPath(reciter.identifier, surahNum);

    if (localPath == null) {
      // Download before playing (same CDN streaming issue as ayah — no Range request support).
      emit(QuranAudioDownloading(reciter: reciter, surahNum: surahNum, progress: 0));
      await _downloadSurah(
        reciter.identifier,
        surahNum,
        onProgress: (p) {
          if (!isClosed) {
            emit(QuranAudioDownloading(
                reciter: reciter, surahNum: surahNum, progress: p));
          }
        },
      );
      if (isClosed) return;
      localPath = await _repository.localSurahPath(reciter.identifier, surahNum);
    }

    emit(QuranAudioPlaying(
      reciter: reciter,
      surahNum: surahNum,
      isSurah: true,
      isBuffering: true,
    ));

    if (localPath != null) {
      await _player.setSourceDeviceFile(localPath);
    } else {
      final url = _repository.surahUrl(reciter.identifier, surahNum);
      await _player.setSourceUrl(url, mimeType: 'audio/mpeg');
    }
    await _player.resume();
  }

  Future<void> pause() async {
    final s = state;
    if (s is! QuranAudioPlaying) return;
    await _player.pause();
    emit(QuranAudioPaused(
      reciter: s.reciter,
      surahNum: s.surahNum,
      ayahNum: s.ayahNum,
      isSurah: s.isSurah,
    ));
  }

  Future<void> resume() async {
    final s = state;
    if (s is! QuranAudioPaused) return;
    await _player.resume();
    emit(QuranAudioPlaying(
      reciter: s.reciter,
      surahNum: s.surahNum,
      ayahNum: s.ayahNum,
      isSurah: s.isSurah,
      isBuffering: false,
    ));
  }

  Future<void> stop() async {
    await _player.stop();
    emit(QuranAudioRecitersLoaded(
      reciters: _reciters,
      selectedReciter: _selectedReciter,
    ));
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> downloadSurah(int surahNum) async {
    final reciter = _selectedReciter;
    if (reciter == null) return;

    emit(QuranAudioDownloading(
      reciter: reciter,
      surahNum: surahNum,
      progress: 0,
    ));

    final result = await _downloadSurah(
      reciter.identifier,
      surahNum,
      onProgress: (p) {
        emit(QuranAudioDownloading(
          reciter: reciter,
          surahNum: surahNum,
          progress: p,
        ));
      },
    );

    result.fold(
      (f) => emit(QuranAudioError(f.message)),
      (_) => emit(QuranAudioRecitersLoaded(
        reciters: _reciters,
        selectedReciter: _selectedReciter,
      )),
    );
  }

  Future<void> downloadPageRange(
      int fromPage, int toPage, Map<int, int> surahFirstPages) async {
    final reciter = _selectedReciter;
    if (reciter == null) return;

    final surahNums = surahFirstPages.entries
        .where((e) => e.value >= fromPage && e.value <= toPage)
        .map((e) => e.key)
        .toList()
      ..sort();

    if (surahNums.isEmpty) return;

    for (int i = 0; i < surahNums.length; i++) {
      final surahNum = surahNums[i];
      emit(QuranAudioDownloading(
        reciter: reciter,
        surahNum: surahNum,
        progress: i / surahNums.length,
      ));
      final result = await _downloadSurah(
        reciter.identifier,
        surahNum,
        onProgress: (p) {
          emit(QuranAudioDownloading(
            reciter: reciter,
            surahNum: surahNum,
            progress: (i + p) / surahNums.length,
          ));
        },
      );
      if (result.isLeft()) break;
    }

    emit(QuranAudioRecitersLoaded(
      reciters: _reciters,
      selectedReciter: _selectedReciter,
    ));
  }

  Future<void> downloadAllForReciter(ReciterEntity reciter) async {
    await BackgroundService.startReciterDownload(
      reciter.identifier,
      reciter.arabicName,
    );
    if (!isClosed) {
      emit(QuranAudioRecitersLoaded(
        reciters: _reciters,
        selectedReciter: _selectedReciter,
      ));
    }
  }

  @override
  Future<void> close() async {
    await _playerStateSub?.cancel();
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _player.dispose();
    return super.close();
  }
}
