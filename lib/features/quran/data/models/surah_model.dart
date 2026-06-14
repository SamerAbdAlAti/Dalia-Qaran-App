import '../../domain/entities/ayah_entity.dart';
import '../../domain/entities/surah_entity.dart';

class AyahModel {
  final int id;
  final String text;

  const AyahModel({required this.id, required this.text});

  factory AyahModel.fromJson(Map<String, dynamic> json) =>
      AyahModel(id: json['id'] as int, text: json['text'] as String);

  AyahEntity toEntity(int surahId) =>
      AyahEntity(id: id, surahId: surahId, text: text);
}

class SurahModel {
  final int id;
  final String name;
  final String transliteration;
  final String type;
  final int totalVerses;
  final List<AyahModel> verses;

  const SurahModel({
    required this.id,
    required this.name,
    required this.transliteration,
    required this.type,
    required this.totalVerses,
    required this.verses,
  });

  factory SurahModel.fromJson(Map<String, dynamic> json) => SurahModel(
        id: json['id'] as int,
        name: json['name'] as String,
        transliteration: json['transliteration'] as String,
        type: json['type'] as String,
        totalVerses: json['total_verses'] as int,
        verses: (json['verses'] as List<dynamic>)
            .map((v) => AyahModel.fromJson(v as Map<String, dynamic>))
            .toList(),
      );

  SurahEntity toEntity() => SurahEntity(
        id: id,
        name: name,
        transliteration: transliteration,
        type: type,
        totalVerses: totalVerses,
      );
}
