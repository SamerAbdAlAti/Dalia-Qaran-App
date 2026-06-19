import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/media_notification_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../domain/entities/reciter_entity.dart';
import '../../domain/repositories/quran_audio_repository.dart';
import '../../domain/usecases/quran_audio_usecases.dart';

enum AudioRepeatMode { none, repeatOne }

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

  final repeatModeNotifier = ValueNotifier<AudioRepeatMode>(AudioRepeatMode.none);
  AudioRepeatMode _repeatMode = AudioRepeatMode.none;

  static const _kSpeedKey = 'quran_audio_speed';
  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  late final ValueNotifier<double> playbackSpeedNotifier;
  double _playbackSpeed = 1.0;

  static const List<String> surahNames = [
    'الفاتحة', 'البقرة', 'آل عمران', 'النساء', 'المائدة', 'الأنعام', 'الأعراف', 'الأنفال', 'التوبة', 'يونس',
    'هود', 'يوسف', 'الرعد', 'إبراهيم', 'الحجر', 'النحل', 'الإسراء', 'الكهف', 'مريم', 'طه',
    'الأنبياء', 'الحج', 'المؤمنون', 'النور', 'الفرقان', 'الشعراء', 'النمل', 'القصص', 'العنكبوت', 'الروم',
    'لقمان', 'السجدة', 'الأحزاب', 'سبأ', 'فاطر', 'يس', 'الصافات', 'ص', 'الزمر', 'غافر',
    'فصلت', 'الشورى', 'الزخرف', 'الدخان', 'الجاثية', 'الأحقاف', 'محمد', 'الفتح', 'الحجرات', 'ق',
    'الذاريات', 'الطور', 'النجم', 'القمر', 'الرحمن', 'الواقعة', 'الحديد', 'المجادلة', 'الحشر', 'الممتحنة',
    'الصف', 'الجمعة', 'المنافقون', 'التغابن', 'الطلاق', 'التحريم', 'الملك', 'القلم', 'الحاقة', 'المعارج',
    'نوح', 'الجن', 'المزمل', 'المدثر', 'القيامة', 'الإنسان', 'المرسلات', 'النبأ', 'النازعات', 'عبس',
    'التكوير', 'الانفطار', 'المطففين', 'الانشقاق', 'البروج', 'الطارق', 'الأعلى', 'الغاشية', 'الفجر', 'البلد',
    'الشمس', 'الليل', 'الضحى', 'الشرح', 'التين', 'العلق', 'القدر', 'البينة', 'الزلزلة', 'العاديات',
    'القارعة', 'التكاثر', 'العصر', 'الهمزة', 'الفيل', 'قريش', 'الماعون', 'الكوثر', 'الكافرون', 'النصر',
    'المسد', 'الإخلاص', 'الفلق', 'الناس',
  ];

  static String surahNameFor(int num) =>
      num >= 1 && num <= surahNames.length ? surahNames[num - 1] : 'سورة $num';

  static const List<int> _surahAyahCounts = [
    7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128,
    111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73,
    54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60,
    49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12, 12, 30, 52, 52, 44,
    28, 28, 20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25, 22, 17, 19, 26, 30,
    20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5,
    4, 5, 6,
  ];

  static int _ayahCountFor(int surahNum) =>
      surahNum >= 1 && surahNum <= _surahAyahCounts.length
          ? _surahAyahCounts[surahNum - 1]
          : 1;

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<String>? _mediaActionSub;

  QuranAudioCubit(
    this._getReciters,
    this._downloadSurah,
    this._repository,
    this._prefs,
  ) : super(QuranAudioInitial()) {
    _playbackSpeed = _prefs.getDouble(_kSpeedKey) ?? 1.0;
    playbackSpeedNotifier = ValueNotifier<double>(_playbackSpeed);
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
    _mediaActionSub = MediaNotificationService.onAction.listen(_onMediaAction);
  }

  void _onPlayerState(PlayerState ps) {
    final s = state;
    if (ps == PlayerState.completed && s is QuranAudioPlaying) {
      unawaited(_handlePlaybackComplete(s));
    }
  }

  Future<void> _handlePlaybackComplete(QuranAudioPlaying s) async {
    if (isClosed) return;

    if (_repeatMode == AudioRepeatMode.repeatOne) {
      if (s.isSurah) {
        await playSurah(s.surahNum);
      } else if (s.ayahNum != null) {
        await playAyah(s.surahNum, s.ayahNum!);
      }
      return;
    }

    // Auto-advance to next ayah or surah
    if (!s.isSurah && s.ayahNum != null) {
      final nextAyah = s.ayahNum! + 1;
      if (nextAyah <= _ayahCountFor(s.surahNum)) {
        if (!isClosed) await playAyah(s.surahNum, nextAyah);
      } else if (s.surahNum < 114) {
        if (!isClosed) await playSurah(s.surahNum + 1);
      } else {
        if (!isClosed) {
          emit(QuranAudioRecitersLoaded(reciters: _reciters, selectedReciter: _selectedReciter));
          unawaited(MediaNotificationService.hide());
        }
      }
    } else {
      if (s.surahNum < 114) {
        if (!isClosed) await playSurah(s.surahNum + 1);
      } else {
        if (!isClosed) {
          emit(QuranAudioRecitersLoaded(reciters: _reciters, selectedReciter: _selectedReciter));
          unawaited(MediaNotificationService.hide());
        }
      }
    }
  }

  void setAudioRepeatMode(AudioRepeatMode mode) {
    _repeatMode = mode;
    repeatModeNotifier.value = mode;
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    playbackSpeedNotifier.value = speed;
    await _prefs.setDouble(_kSpeedKey, speed);
    await _player.setPlaybackRate(speed);
  }

  void cyclePlaybackSpeed() {
    final idx = _speeds.indexOf(_playbackSpeed);
    final next = _speeds[(idx + 1) % _speeds.length];
    unawaited(setPlaybackSpeed(next));
  }

  Future<void> playNext() async {
    final s = state;
    final int surahNum;
    final int ayahNum;
    final bool isSurah;
    if (s is QuranAudioPlaying) {
      surahNum = s.surahNum; ayahNum = s.ayahNum ?? 1; isSurah = s.isSurah;
    } else if (s is QuranAudioPaused) {
      surahNum = s.surahNum; ayahNum = s.ayahNum ?? 1; isSurah = s.isSurah;
    } else { return; }

    if (!isSurah) {
      if (ayahNum < _ayahCountFor(surahNum)) {
        await playAyah(surahNum, ayahNum + 1);
      } else if (surahNum < 114) {
        await playSurah(surahNum + 1);
      }
    } else {
      if (surahNum < 114) { await playSurah(surahNum + 1); }
    }
  }

  Future<void> playPrev() async {
    final s = state;
    final int surahNum;
    final int ayahNum;
    final bool isSurah;
    if (s is QuranAudioPlaying) {
      surahNum = s.surahNum; ayahNum = s.ayahNum ?? 1; isSurah = s.isSurah;
    } else if (s is QuranAudioPaused) {
      surahNum = s.surahNum; ayahNum = s.ayahNum ?? 1; isSurah = s.isSurah;
    } else { return; }

    if (!isSurah) {
      if (ayahNum > 1) {
        await playAyah(surahNum, ayahNum - 1);
      } else if (surahNum > 1) {
        await playAyah(surahNum - 1, _ayahCountFor(surahNum - 1));
      }
    } else {
      if (surahNum > 1) { await playSurah(surahNum - 1); }
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

  void _onMediaAction(String action) {
    if (action == 'play') {
      unawaited(resume());
    } else if (action == 'pause') {
      unawaited(pause());
    } else if (action == 'next') {
      unawaited(playNext());
    } else if (action == 'prev') {
      unawaited(playPrev());
    }
  }

  void _showMediaNotification({required bool isPlaying, required int surahNum, int? ayahNum}) {
    final name = surahNameFor(surahNum);
    final subtitle = ayahNum != null ? 'آية $ayahNum' : (_selectedReciter?.arabicName ?? 'القرآن الكريم');
    unawaited(MediaNotificationService.show(
      surahName: name, subtitle: subtitle, isPlaying: isPlaying, surahNum: surahNum,
    ));
  }

  void _updateMediaNotification({required bool isPlaying, required int surahNum, int? ayahNum}) {
    final name = surahNameFor(surahNum);
    final subtitle = ayahNum != null ? 'آية $ayahNum' : (_selectedReciter?.arabicName ?? 'القرآن الكريم');
    unawaited(MediaNotificationService.update(
      surahName: name, subtitle: subtitle, isPlaying: isPlaying, surahNum: surahNum,
    ));
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
    _showMediaNotification(isPlaying: true, surahNum: surahNum, ayahNum: ayahNum);
    // Prefer a permanently-downloaded ayah ("مقطعة" bulk download) — skips
    // network entirely. Falls back to the temp-cache-on-demand path otherwise.
    // CDN doesn't support HTTP Range requests → Android MediaPlayer fails with error (1, -2147483648).
    final persistentPath =
        await _repository.localAyahPath(reciter.identifier, surahNum, ayahNum);
    final localPath = persistentPath ??
        await _cacheAyah(reciter.identifier, surahNum, ayahNum, url);
    if (isClosed) return;
    if (localPath == null || localPath.startsWith('__error_')) {
      final code = localPath?.replaceFirst('__error_', '') ?? '?';
      // null (network exception) → if full surah is cached locally, use it
      if (code == '?') {
        final surahPath = await _repository.localSurahPath(reciter.identifier, surahNum);
        if (surahPath != null && !isClosed) {
          // Switching to surah-mode playback — surface this so the user
          // understands why per-ayah highlighting/auto-advance stop applying.
          emit(QuranAudioError('سيُشغَّل صوت السورة كاملة'));
          await Future.delayed(const Duration(seconds: 1));
          if (!isClosed) await playSurah(surahNum);
          return;
        }
        unawaited(MediaNotificationService.hide());
        if (!isClosed) emit(QuranAudioError('تعذّر تحميل الآية، تحقق من الاتصال بالإنترنت'));
        return;
      }
      // HTTP error (4xx/5xx) → CDN doesn't support per-ayah for this reciter
      // Fall back to the full surah automatically
      emit(QuranAudioError('سيُشغَّل صوت السورة كاملة'));
      await Future.delayed(const Duration(seconds: 1));
      if (!isClosed) await playSurah(surahNum);
      return;
    }
    try {
      await _player.setSourceDeviceFile(localPath);
      await _player.resume();
    } catch (_) {
      // Cached file is corrupted (e.g. CDN returned an HTML error page as
      // 200 OK) — delete it so the next attempt re-downloads, then fall back.
      unawaited(File(localPath).delete().catchError((_) => File(localPath)));
      if (isClosed) return;
      final surahPath = await _repository.localSurahPath(reciter.identifier, surahNum);
      if (surahPath != null && !isClosed) {
        await playSurah(surahNum);
      } else if (!isClosed) {
        unawaited(MediaNotificationService.hide());
        emit(QuranAudioError('تعذّر تشغيل الآية، حاول مرة أخرى'));
      }
      return;
    }
    if (_playbackSpeed != 1.0) unawaited(_player.setPlaybackRate(_playbackSpeed));
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
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty && _looksLikeAudioNotHtml(res.bodyBytes)) {
        await file.writeAsBytes(res.bodyBytes);
        return file.path;
      }
      // Return status code so caller can emit a specific error
      return '__error_${res.statusCode}';
    } catch (_) {}
    return null;
  }

  // Some CDNs return a 200 OK with an HTML error/redirect page instead of
  // the audio file — guard against caching that as if it were valid audio.
  // Deny-list (reject only obvious HTML) rather than allow-list (require an
  // exact MP3 signature) — a strict signature check risks false-rejecting
  // legitimate files whose header doesn't match the exact bytes expected,
  // which would silently break per-ayah playback for reciters/CDNs that are
  // otherwise working fine.
  static bool _looksLikeAudioNotHtml(List<int> bytes) {
    if (bytes.length < 16) return false;
    final head = String.fromCharCodes(bytes.take(64)).toLowerCase();
    if (head.contains('<html') ||
        head.contains('<!doctype') ||
        head.contains('<?xml')) {
      return false;
    }
    return true;
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
        onProgress: (p, _) {
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
    _showMediaNotification(isPlaying: true, surahNum: surahNum);

    try {
      if (localPath != null) {
        await _player.setSourceDeviceFile(localPath);
      } else {
        final url = _repository.surahUrl(reciter.identifier, surahNum);
        await _player.setSourceUrl(url, mimeType: 'audio/mpeg');
      }
      await _player.resume();
    } catch (_) {
      // audioplayers can throw "Bad state: No element" when the prepared
      // event races with a concurrent stop/dispose (e.g. rapid play taps).
      if (!isClosed) {
        unawaited(MediaNotificationService.hide());
        emit(QuranAudioError('تعذّر تشغيل السورة، حاول مرة أخرى'));
      }
      return;
    }
    if (_playbackSpeed != 1.0) unawaited(_player.setPlaybackRate(_playbackSpeed));
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
    _updateMediaNotification(isPlaying: false, surahNum: s.surahNum, ayahNum: s.ayahNum);
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
    _updateMediaNotification(isPlaying: true, surahNum: s.surahNum, ayahNum: s.ayahNum);
  }

  Future<void> stop() async {
    await _player.stop();
    emit(QuranAudioRecitersLoaded(
      reciters: _reciters,
      selectedReciter: _selectedReciter,
    ));
    unawaited(MediaNotificationService.hide());
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
      onProgress: (p, _) {
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
        onProgress: (p, _) {
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
    const total = 114;
    // Clear any stale notification from a previous background download.
    unawaited(NotificationService.cancelDownloadNotification());

    int downloaded = 0;
    final List<int> failed = [];

    for (int surahNum = 1; surahNum <= total; surahNum++) {
      if (isClosed) break;

      final alreadyDone =
          await _repository.isSurahDownloaded(reciter.identifier, surahNum);
      if (alreadyDone) {
        downloaded++;
        continue;
      }

      emit(QuranAudioDownloading(
        reciter: reciter,
        surahNum: surahNum,
        progress: downloaded / total,
      ));

      unawaited(NotificationService.showDownloadProgress(
        reciterName: reciter.arabicName,
        surahNum: surahNum,
        surahName: surahNameFor(surahNum),
        total: total,
      ));

      // Re-post the notification on every chunk (throttled) — this also
      // means a swiped-away notification reappears within ~1s instead of
      // waiting for the next surah to start, and shows live speed.
      var lastNotifMs = 0;
      var lastSpeedBytes = 0;
      var lastSpeedMs = DateTime.now().millisecondsSinceEpoch;
      var speedKBps = 0.0;

      final result = await _downloadSurah(
        reciter.identifier,
        surahNum,
        onProgress: (p, receivedBytes) {
          if (isClosed) return;
          emit(QuranAudioDownloading(
            reciter: reciter,
            surahNum: surahNum,
            progress: (downloaded + p) / total,
          ));
          final now = DateTime.now().millisecondsSinceEpoch;
          final deltaMs = now - lastSpeedMs;
          if (deltaMs >= 2000) {
            speedKBps = (receivedBytes - lastSpeedBytes) * 1000.0 / (deltaMs * 1024.0);
            lastSpeedBytes = receivedBytes;
            lastSpeedMs = now;
          }
          if (now - lastNotifMs >= 800) {
            lastNotifMs = now;
            unawaited(NotificationService.showDownloadProgress(
              reciterName: reciter.arabicName,
              surahNum: surahNum,
              surahName: surahNameFor(surahNum),
              total: total,
              surahPercent: (p * 100).round(),
              speedKBps: speedKBps.abs(),
            ));
          }
        },
      );

      result.fold(
        (f) => failed.add(surahNum),
        (_) => downloaded++,
      );

      // Stop on hard failures (connection lost etc.).
      if (failed.length > 3) break;
    }

    unawaited(NotificationService.cancelDownloadNotification());
    if (failed.isEmpty) {
      unawaited(NotificationService.showDownloadComplete(
          reciterName: reciter.arabicName));
    } else {
      unawaited(NotificationService.showDownloadComplete(
          reciterName: reciter.arabicName, failedCount: failed.length));
    }

    if (!isClosed) {
      emit(QuranAudioRecitersLoaded(
        reciters: _reciters,
        selectedReciter: _selectedReciter,
      ));
    }
  }

  /// تحميل سورة واحدة محدَّدة لقارئ مُحدَّد — كاملة أو مقطّعة آية بآية.
  /// بخلاف [downloadSurah]، تأخذ القارئ صراحةً فلا تعتمد على القارئ المختار
  /// حالياً (مفيد عند التحميل من ورقة اختيار القارئ).
  Future<void> downloadSurahForReciter(
    ReciterEntity reciter,
    int surahNum, {
    required bool segmented,
  }) async {
    unawaited(NotificationService.cancelDownloadNotification());
    final name = surahNameFor(surahNum);

    if (!segmented) {
      emit(QuranAudioDownloading(reciter: reciter, surahNum: surahNum, progress: 0));
      unawaited(NotificationService.showDownloadProgress(
        reciterName: reciter.arabicName, surahNum: surahNum, surahName: name, total: 1,
      ));
      var lastNotifMs = 0;
      var lastSpeedBytes = 0;
      var lastSpeedMs = DateTime.now().millisecondsSinceEpoch;
      var speedKBps = 0.0;
      final result = await _downloadSurah(
        reciter.identifier,
        surahNum,
        onProgress: (p, receivedBytes) {
          if (isClosed) return;
          emit(QuranAudioDownloading(reciter: reciter, surahNum: surahNum, progress: p));
          final now = DateTime.now().millisecondsSinceEpoch;
          final deltaMs = now - lastSpeedMs;
          if (deltaMs >= 2000) {
            speedKBps = (receivedBytes - lastSpeedBytes) * 1000.0 / (deltaMs * 1024.0);
            lastSpeedBytes = receivedBytes;
            lastSpeedMs = now;
          }
          if (now - lastNotifMs >= 800) {
            lastNotifMs = now;
            unawaited(NotificationService.showDownloadProgress(
              reciterName: reciter.arabicName,
              surahNum: surahNum,
              surahName: name,
              total: 1,
              surahPercent: (p * 100).round(),
              speedKBps: speedKBps.abs(),
            ));
          }
        },
      );
      unawaited(NotificationService.cancelDownloadNotification());
      result.fold(
        (f) => emit(QuranAudioError(f.message)),
        (_) => unawaited(NotificationService.showDownloadComplete(reciterName: reciter.arabicName)),
      );
    } else {
      final ayahCount = _ayahCountFor(surahNum);
      int done = 0;
      int failedCount = 0;
      for (int ayahNum = 1; ayahNum <= ayahCount; ayahNum++) {
        if (isClosed) break;
        final already =
            await _repository.isAyahDownloaded(reciter.identifier, surahNum, ayahNum);
        if (already) {
          done++;
          continue;
        }
        emit(QuranAudioDownloading(
          reciter: reciter, surahNum: surahNum, progress: done / ayahCount));
        unawaited(NotificationService.showDownloadProgress(
          reciterName: reciter.arabicName,
          surahNum: surahNum,
          surahName: name,
          total: 1,
          surahPercent: ((done / ayahCount) * 100).round(),
        ));
        final result =
            await _repository.downloadAyah(reciter.identifier, surahNum, ayahNum);
        result.fold((f) => failedCount++, (_) => done++);
        if (failedCount > 10) break;
      }
      unawaited(NotificationService.cancelDownloadNotification());
      if (!isClosed) {
        unawaited(NotificationService.showDownloadComplete(
          reciterName: reciter.arabicName,
          failedCount: failedCount,
        ));
      }
    }

    if (!isClosed) {
      emit(QuranAudioRecitersLoaded(reciters: _reciters, selectedReciter: _selectedReciter));
    }
  }

  /// تحميل دائم لكل آية على حدة ("مقطعة") لكل القرآن — بديل عن
  /// [downloadAllForReciter] الذي يُحمِّل السور كاملة ("غير مقطعة").
  Future<void> downloadAllAyahsForReciter(ReciterEntity reciter) async {
    const totalSurahs = 114;
    final totalAyahs = _surahAyahCounts.reduce((a, b) => a + b);
    unawaited(NotificationService.cancelDownloadNotification());

    int downloadedAyahs = 0;
    int failedCount = 0;

    for (int surahNum = 1; surahNum <= totalSurahs; surahNum++) {
      if (isClosed) break;
      final ayahCount = _ayahCountFor(surahNum);

      unawaited(NotificationService.showDownloadProgress(
        reciterName: reciter.arabicName,
        surahNum: surahNum,
        total: totalSurahs,
        surahPercent: ((downloadedAyahs / totalAyahs) * 100).round(),
      ));

      for (int ayahNum = 1; ayahNum <= ayahCount; ayahNum++) {
        if (isClosed) break;

        final already =
            await _repository.isAyahDownloaded(reciter.identifier, surahNum, ayahNum);
        if (already) {
          downloadedAyahs++;
          continue;
        }

        emit(QuranAudioDownloading(
          reciter: reciter,
          surahNum: surahNum,
          progress: downloadedAyahs / totalAyahs,
        ));

        final result =
            await _repository.downloadAyah(reciter.identifier, surahNum, ayahNum);
        result.fold((f) => failedCount++, (_) => downloadedAyahs++);

        // Stop on sustained failure (connection lost etc.) — isolated CDN
        // gaps for individual ayahs are common and shouldn't abort the run.
        if (failedCount > 30) break;
      }
      if (failedCount > 30) break;
    }

    unawaited(NotificationService.cancelDownloadNotification());
    if (failedCount == 0) {
      unawaited(NotificationService.showDownloadComplete(reciterName: reciter.arabicName));
    } else {
      unawaited(NotificationService.showDownloadComplete(
          reciterName: reciter.arabicName, failedCount: failedCount));
    }

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
    await _mediaActionSub?.cancel();
    unawaited(MediaNotificationService.hide());
    await _player.dispose();
    repeatModeNotifier.dispose();
    playbackSpeedNotifier.dispose();
    return super.close();
  }
}
