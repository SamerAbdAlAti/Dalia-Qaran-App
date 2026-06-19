import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class QuranAudioLocalDatasource {
  Future<Directory> _audioDir(String identifier) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/quran_audio/$identifier');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _fileName(int surahNum) =>
      '${surahNum.toString().padLeft(3, '0')}.mp3';

  Future<String> downloadSurah(
    String url,
    String identifier,
    int surahNum, {
    void Function(double progress, int receivedBytes)? onProgress,
  }) async {
    final dir   = await _audioDir(identifier);
    final name  = surahNum.toString().padLeft(3, '0');
    final finalFile = File('${dir.path}/$name.mp3');
    final tempFile  = File('${dir.path}/$name.tmp');

    final resumeFrom = tempFile.existsSync() ? tempFile.lengthSync() : 0;

    final request = http.Request('GET', Uri.parse(url));
    request.headers['User-Agent'] = 'Daliya/1.0 (Android; Quran App)';
    request.headers['Accept'] = 'audio/mpeg, audio/*, */*';
    if (resumeFrom > 0) request.headers['Range'] = 'bytes=$resumeFrom-';

    final response = await request.send().timeout(const Duration(seconds: 60));

    if (response.statusCode == 416) {
      // الملف المؤقت أكبر من الملف الفعلي — نحذفه ونعيد التحميل من البداية
      await response.stream.drain<void>();
      if (tempFile.existsSync()) await tempFile.delete();
      throw Exception('HTTP 416 — سيُعاد التحميل من البداية');
    }

    if (response.statusCode != 200 && response.statusCode != 206) {
      await response.stream.drain<void>();
      throw Exception('فشل التحميل: ${response.statusCode}');
    }

    final total = (response.contentLength ?? 0) + resumeFrom;
    int received = resumeFrom;
    final writeMode = response.statusCode == 206 ? FileMode.append : FileMode.write;
    final sink = tempFile.openWrite(mode: writeMode);

    try {
      await Future(() async {
        await for (final chunk
            in response.stream.timeout(const Duration(seconds: 60))) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress?.call(received / total, received);
        }
      }).timeout(const Duration(minutes: 8));
      await sink.flush();
      await sink.close();
      if (await finalFile.exists()) await finalFile.delete();
      await tempFile.rename(finalFile.path);
      return finalFile.path;
    } catch (e) {
      await sink.flush();
      await sink.close();
      // نحتفظ بالملف المؤقت لاستئناف التحميل في المحاولة التالية
      rethrow;
    }
  }

  Future<bool> isSurahDownloaded(String identifier, int surahNum) async {
    final dir = await _audioDir(identifier);
    final file = File('${dir.path}/${_fileName(surahNum)}');
    return file.existsSync() && file.lengthSync() > 0;
  }

  Future<String?> localPath(String identifier, int surahNum) async {
    final dir = await _audioDir(identifier);
    final file = File('${dir.path}/${_fileName(surahNum)}');
    if (file.existsSync() && file.lengthSync() > 0) return file.path;
    return null;
  }

  Future<void> delete(String identifier, int surahNum) async {
    final dir = await _audioDir(identifier);
    final file = File('${dir.path}/${_fileName(surahNum)}');
    if (await file.exists()) await file.delete();
  }

  // ─── Per-ayah persistent downloads ("مقطعة") — separate from the
  // temp-cache used for instant single-ayah playback in quran_audio_cubit.

  Future<Directory> _ayahDir(String identifier) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/quran_audio_ayahs/$identifier');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _ayahFileName(int surahNum, int ayahNum) =>
      '${surahNum.toString().padLeft(3, '0')}_${ayahNum.toString().padLeft(3, '0')}.mp3';

  Future<String> downloadAyah(
      String url, String identifier, int surahNum, int ayahNum) async {
    final dir = await _ayahDir(identifier);
    final file = File('${dir.path}/${_ayahFileName(surahNum, ayahNum)}');
    if (file.existsSync() && file.lengthSync() > 0) return file.path;

    final response = await http.get(Uri.parse(url), headers: {
      'User-Agent': 'Daliya/1.0 (Android; Quran App)',
      'Accept': 'audio/mpeg, audio/*, */*',
    }).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw Exception('فشل تحميل الآية: ${response.statusCode}');
    }
    await file.writeAsBytes(response.bodyBytes);
    return file.path;
  }

  Future<bool> isAyahDownloaded(
      String identifier, int surahNum, int ayahNum) async {
    final dir = await _ayahDir(identifier);
    final file = File('${dir.path}/${_ayahFileName(surahNum, ayahNum)}');
    return file.existsSync() && file.lengthSync() > 0;
  }

  Future<String?> localAyahPath(
      String identifier, int surahNum, int ayahNum) async {
    final dir = await _ayahDir(identifier);
    final file = File('${dir.path}/${_ayahFileName(surahNum, ayahNum)}');
    if (file.existsSync() && file.lengthSync() > 0) return file.path;
    return null;
  }
}
