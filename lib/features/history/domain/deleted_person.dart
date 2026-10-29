/// Một người đã bị xóa mềm (chỉ admin đọc được).
class DeletedPerson {
  const DeletedPerson({
    required this.id,
    required this.fullName,
    this.birthYear,
    this.deathYear,
    required this.deletedAt,
  });

  factory DeletedPerson.fromJson(Map<String, dynamic> json) {
    return DeletedPerson(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      birthYear: json['birth_year'] as int?,
      deathYear: json['death_year'] as int?,
      deletedAt: DateTime.parse(json['deleted_at'] as String),
    );
  }

  final String id;
  final String fullName;
  final int? birthYear;
  final int? deathYear;
  final DateTime deletedAt;

  /// Dòng mô tả năm sinh, năm mất.
  String get lifeSpan {
    final born = birthYear;
    final died = deathYear;
    if (born != null && died != null) {
      return 'Sinh $born, mất $died';
    }
    if (born != null) {
      return 'Sinh $born';
    }
    if (died != null) {
      return 'Mất $died';
    }
    return 'Chưa rõ năm sinh, năm mất';
  }
}