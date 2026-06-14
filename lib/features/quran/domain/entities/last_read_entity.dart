import 'package:equatable/equatable.dart';

class LastReadEntity extends Equatable {
  final int surahId;
  final String surahName;
  final int ayahId;

  const LastReadEntity({
    required this.surahId,
    required this.surahName,
    required this.ayahId,
  });

  @override
  List<Object?> get props => [surahId, surahName, ayahId];

  LastReadEntity copyWith({int? surahId, String? surahName, int? ayahId}) =>
      LastReadEntity(
        surahId: surahId ?? this.surahId,
        surahName: surahName ?? this.surahName,
        ayahId: ayahId ?? this.ayahId,
      );
}
