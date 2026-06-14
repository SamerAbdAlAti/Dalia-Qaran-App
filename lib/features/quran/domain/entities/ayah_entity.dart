import 'package:equatable/equatable.dart';

class AyahEntity extends Equatable {
  final int id;
  final int surahId;
  final String text;

  const AyahEntity({
    required this.id,
    required this.surahId,
    required this.text,
  });

  @override
  List<Object?> get props => [id, surahId, text];

  AyahEntity copyWith({int? id, int? surahId, String? text}) => AyahEntity(
        id: id ?? this.id,
        surahId: surahId ?? this.surahId,
        text: text ?? this.text,
      );
}
