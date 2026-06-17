import '../../domain/entities/reciter_entity.dart';

class ReciterModel extends ReciterEntity {
  const ReciterModel({
    required super.identifier,
    required super.arabicName,
    required super.englishName,
  });

  factory ReciterModel.fromJson(Map<String, dynamic> json) => ReciterModel(
        identifier: json['identifier'] as String,
        arabicName: json['name'] as String,
        englishName: json['englishName'] as String,
      );

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'name': arabicName,
        'englishName': englishName,
      };
}
