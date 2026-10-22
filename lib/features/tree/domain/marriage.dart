import 'package:familytree/core/utils/json_parsing.dart';

enum MarriageStatus {
  married,
  divorced,
  widowed;

  static MarriageStatus fromString(String? value) => switch (value) {
        'divorced' => MarriageStatus.divorced,
        'widowed' => MarriageStatus.widowed,
        _ => MarriageStatus.married,
      };
}

class Marriage {
  const Marriage({
    required this.id,
    required this.person1Id,
    required this.person2Id,
    required this.status,
    this.startDate,
    this.endDate,
    this.notes,
  });

  final String id;
  final String person1Id;
  final String person2Id;
  final MarriageStatus status;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? notes;

  factory Marriage.fromJson(Map<String, dynamic> json) {
    return Marriage(
      id: json['id'] as String,
      person1Id: json['person1_id'] as String,
      person2Id: json['person2_id'] as String,
      status: MarriageStatus.fromString(json['status'] as String?),
      startDate: parseDate(json['start_date']),
      endDate: parseDate(json['end_date']),
      notes: json['notes'] as String?,
    );
  }
}