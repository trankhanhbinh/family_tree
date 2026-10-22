import 'package:familytree/core/utils/json_parsing.dart';

enum Gender {
  male,
  female,
  other;

  static Gender fromString(String? value) => switch (value) {
        'male' => Gender.male,
        'female' => Gender.female,
        _ => Gender.other,
      };
}

class Person {
  const Person({
    required this.id,
    required this.fullName,
    this.otherName,
    required this.gender,
    this.branchId,
    this.generation,
    this.birthDate,
    this.birthYear,
    this.birthPlace,
    required this.isAlive,
    this.deathDate,
    this.deathYear,
    this.burialPlace,
    this.memorialLunarDay,
    this.memorialLunarMonth,
    required this.memorialIsLeap,
    this.notes,
    this.deletedAt,
  });

  final String id;
  final String fullName;
  final String? otherName;
  final Gender gender;
  final String? branchId;
  final int? generation;
  final DateTime? birthDate;
  final int? birthYear;
  final String? birthPlace;
  final bool isAlive;
  final DateTime? deathDate;
  final int? deathYear;
  final String? burialPlace;
  final int? memorialLunarDay;
  final int? memorialLunarMonth;
  final bool memorialIsLeap;
  final String? notes;
  final DateTime? deletedAt;

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      otherName: json['other_name'] as String?,
      gender: Gender.fromString(json['gender'] as String?),
      branchId: json['branch_id'] as String?,
      generation: json['generation'] as int?,
      birthDate: parseDate(json['birth_date']),
      birthYear: json['birth_year'] as int?,
      birthPlace: json['birth_place'] as String?,
      isAlive: json['is_alive'] as bool? ?? true,
      deathDate: parseDate(json['death_date']),
      deathYear: json['death_year'] as int?,
      burialPlace: json['burial_place'] as String?,
      memorialLunarDay: json['memorial_lunar_day'] as int?,
      memorialLunarMonth: json['memorial_lunar_month'] as int?,
      memorialIsLeap: json['memorial_is_leap'] as bool? ?? false,
      notes: json['notes'] as String?,
      deletedAt: parseDate(json['deleted_at']),
    );
  }
}