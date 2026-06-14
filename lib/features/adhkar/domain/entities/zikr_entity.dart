import 'package:equatable/equatable.dart';

enum ZikrCategory { morning, evening, afterPrayer }

extension ZikrCategoryX on ZikrCategory {
  String get label => switch (this) {
        ZikrCategory.morning => 'أذكار الصباح',
        ZikrCategory.evening => 'أذكار المساء',
        ZikrCategory.afterPrayer => 'أذكار بعد الصلاة',
      };
}

class ZikrEntity extends Equatable {
  final int id;
  final String text;
  final String? source;
  final String? benefit;
  final int repeatCount;
  final ZikrCategory category;

  const ZikrEntity({
    required this.id,
    required this.text,
    this.source,
    this.benefit,
    required this.repeatCount,
    required this.category,
  });

  @override
  List<Object?> get props => [id, category];
}
