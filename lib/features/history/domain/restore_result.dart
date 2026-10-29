import 'package:familytree/features/history/domain/history_describer.dart';

/// Một quan hệ không dựng lại được khi khôi phục.
class SkippedRelation {
  const SkippedRelation({
    required this.entityType,
    required this.entityId,
    required this.reason,
    this.otherPersonId,
    this.personIs,
  });

  factory SkippedRelation.fromJson(Map<String, dynamic> json) {
    return SkippedRelation(
      entityType: json['entity_type'] as String? ?? '',
      entityId: json['entity_id'] as String? ?? '',
      reason: json['reason'] as String? ?? 'OTHER',
      otherPersonId: json['other_person_id'] as String?,
      personIs: json['person_is'] as String?,
    );
  }

  /// parent_child hoặc marriage.
  final String entityType;
  final String entityId;

  /// PERSON_MISSING / ALREADY_EXISTS / CYCLE_DETECTED / OTHER
  final String reason;
  final String? otherPersonId;

  /// 'parent' hoặc 'child': vai của người được khôi phục (chỉ với parent_child).
  final String? personIs;
}

/// Kết quả hàm admin_restore_person.
class RestoreResult {
  const RestoreResult({
    required this.personId,
    required this.personName,
    required this.hadHistory,
    required this.restoredRelations,
    required this.skipped,
  });

  factory RestoreResult.fromJson(Map<String, dynamic> json) {
    final skippedRaw = json['skipped'];
    return RestoreResult(
      personId: json['person_id'] as String,
      personName: json['person_name'] as String? ?? '',
      hadHistory: json['had_history'] as bool? ?? false,
      restoredRelations: (json['restored_relations'] as num?)?.toInt() ?? 0,
      skipped: [
        if (skippedRaw is List)
          for (final item in skippedRaw)
            if (item is Map)
              SkippedRelation.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

  final String personId;
  final String personName;
  final bool hadHistory;
  final int restoredRelations;
  final List<SkippedRelation> skipped;
}

String _reasonText(String reason) {
  return switch (reason) {
    'PERSON_MISSING' => 'người này đã bị xóa',
    'ALREADY_EXISTS' => 'quan hệ này đã có rồi',
    'CYCLE_DETECTED' => 'sẽ làm một người thành tổ tiên của chính mình',
    _ => 'không dựng lại được',
  };
}

String _skippedTitle(SkippedRelation item, HistoryNameLookup nameOf) {
  final name = nameOf(item.otherPersonId) ?? '(không rõ)';
  if (item.entityType == 'marriage') {
    return 'Vợ/chồng $name';
  }
  return switch (item.personIs) {
    'parent' => 'Con $name',
    'child' => 'Cha/mẹ $name',
    _ => 'Quan hệ với $name',
  };
}

/// Nội dung hộp thoại kết quả sau khi khôi phục.
String describeRestoreResult(RestoreResult result, HistoryNameLookup nameOf) {
  final lines = <String>['Đã đưa ${result.personName} trở lại gia phả.'];

  if (!result.hadHistory) {
    lines.add(
      'Không tìm thấy lịch sử lần xóa, nên chưa dựng lại quan hệ nào. '
      'Hãy thêm lại quan hệ bằng các nút trên hồ sơ.',
    );
    return lines.join('\n');
  }

  if (result.restoredRelations > 0) {
    lines.add('Đã dựng lại ${result.restoredRelations} quan hệ.');
  } else if (result.skipped.isEmpty) {
    lines.add('Lúc xóa, người này không có quan hệ nào bị gỡ.');
  }

  if (result.skipped.isNotEmpty) {
    lines.add('');
    lines.add('Bỏ qua ${result.skipped.length} quan hệ:');
    for (final item in result.skipped) {
      lines.add('• ${_skippedTitle(item, nameOf)}: ${_reasonText(item.reason)}');
    }
    lines.add('');
    lines.add('Có thể thêm lại các quan hệ này bằng các nút trên hồ sơ.');
  }

  return lines.join('\n');
}