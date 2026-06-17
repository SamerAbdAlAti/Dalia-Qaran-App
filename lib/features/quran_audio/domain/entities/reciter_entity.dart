import 'package:equatable/equatable.dart';

class ReciterEntity extends Equatable {
  final String identifier;
  final String arabicName;
  final String englishName;

  const ReciterEntity({
    required this.identifier,
    required this.arabicName,
    required this.englishName,
  });

  @override
  List<Object?> get props => [identifier];
}
