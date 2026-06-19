import 'dart:convert';
import 'package:http/http.dart' as http;

class TafsirRemoteDatasource {
  // التفسير الميسر/المنتخب — نفس مزود alquran.cloud المستخدم لقائمة القراء.
  static const _edition = 'ar.muntakhab';

  Future<String> fetchTafsir(int surahId, int ayahNum) async {
    final response = await http
        .get(Uri.parse(
            'https://api.alquran.cloud/v1/ayah/$surahId:$ayahNum/$_edition'))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('فشل تحميل التفسير: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return data['text'] as String;
  }
}
