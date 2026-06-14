import 'package:equatable/equatable.dart';

class SurahEntity extends Equatable {
  final int id;
  final String name;
  final String transliteration;
  final String type;
  final int totalVerses;

  const SurahEntity({
    required this.id,
    required this.name,
    required this.transliteration,
    required this.type,
    required this.totalVerses,
  });

  @override
  List<Object?> get props => [id, name, transliteration, type, totalVerses];

  SurahEntity copyWith({
    int? id,
    String? name,
    String? transliteration,
    String? type,
    int? totalVerses,
  }) =>
      SurahEntity(
        id: id ?? this.id,
        name: name ?? this.name,
        transliteration: transliteration ?? this.transliteration,
        type: type ?? this.type,
        totalVerses: totalVerses ?? this.totalVerses,
      );
}
