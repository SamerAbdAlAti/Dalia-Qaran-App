import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/reciter_model.dart';

class QuranAudioRemoteDatasource {
  Future<List<ReciterModel>> fetchReciters() async {
    final response = await http
        .get(Uri.parse('https://api.alquran.cloud/v1/edition/format/audio'))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('فشل تحميل قائمة القراء: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>;

    return data
        .cast<Map<String, dynamic>>()
        .where((e) =>
            (e['language'] as String?) == 'ar' &&
            (e['type'] as String?) == 'versebyverse')
        .map(ReciterModel.fromJson)
        .toList();
  }
}
