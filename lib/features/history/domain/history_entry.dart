/// Số dòng lịch sử tải mỗi trang.
const int kHistoryPageSize = 50;

/// Các khóa trong before_data/after_data có thể trỏ tới một người
/// (parent_child, marriages, person_photos).
const List<String> kPersonRefKeys = [
  'person_id',
  'parent_id',
  'child_id',
  'person1_id',
  'person2_id',
];

/// Bộ lọc `or` của PostgREST: dòng của chính người đó (entity_id)
/// hoặc dòng quan hệ/hôn nhân/ảnh có nhắc tới người đó.
String personHistoryFilter(String personId) {
  final parts = <String>['entity_id.eq.$personId'];
  for (final key in kPersonRefKeys) {
    parts.add('before_data->>$key.eq.$personId');
    parts.add('after_data->>$key.eq.$personId');
  }
  return parts.join(',');
}

Map<String, dynamic>? _mapOrNull(Object? value) {
  return value is Map ? Map<String, dynamic>.from(value) : null;
}

/// Một dòng của bảng change_history.
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    this.before,
    this.after,
    required this.actorName,
    this.actorUserId,
    this.requestId,
    required this.createdAtRaw,
    required this.createdAt,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['created_at'] as String;
    return HistoryEntry(
      id: json['id'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      action: json['action'] as String,
      before: _mapOrNull(json['before_data']),
      after: _mapOrNull(json['after_data']),
      actorName: json['actor_name'] as String? ?? 'Admin',
      actorUserId: json['actor_user_id'] as String?,
      requestId: json['request_id'] as String?,
      createdAtRaw: createdRaw,
      createdAt: DateTime.parse(createdRaw),
    );
  }

  final String id;
  final String entityType;
  final String entityId;

  /// create / update / delete / restore
  final String action;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;
  final String actorName;
  final String? actorUserId;
  final String? requestId;

  /// Chuỗi thời gian gốc từ server (giữ nguyên micro giây, dùng làm khóa gom nhóm).
  final String createdAtRaw;
  final DateTime createdAt;

  /// Dữ liệu để hiển thị: bản mới nếu có, không thì bản cũ (dòng bị xóa thật).
  Map<String, dynamic>? get data => after ?? before;

  /// Mọi dòng của MỘT giao dịch có cùng created_at (now() của giao dịch)
  /// và cùng người thực hiện. KHÔNG dùng request_id: khi duyệt gói,
  /// mỗi dòng mang id của từng dòng đề xuất, không phải id cả gói.
  String get groupKey => '${actorUserId ?? ''}|$createdAtRaw';
}

/// Một "lần thay đổi" = các dòng lịch sử của cùng một giao dịch.
class HistoryGroup {
  const HistoryGroup({required this.key, required this.entries});

  final String key;
  final List<HistoryEntry> entries;

  String get actorName => entries.first.actorName;

  DateTime get createdAt => entries.first.createdAt;
}

/// Thứ tự hiển thị trong một nhóm: khôi phục, tạo, sửa, rồi xóa
/// (xóa quan hệ trước khi xóa người).
int historyDisplayRank(HistoryEntry entry) {
  if (entry.action == 'restore') {
    return 5;
  }
  if (entry.action == 'create') {
    return switch (entry.entityType) {
      'branch' => 9,
      'person' => 10,
      'parent_child' => 20,
      'marriage' => 21,
      'person_photo' => 22,
      _ => 29,
    };
  }
  if (entry.action == 'update') {
    return 40;
  }
  if (entry.action == 'delete') {
    return switch (entry.entityType) {
      'person_photo' => 50,
      'parent_child' => 51,
      'marriage' => 52,
      'person' => 60,
      _ => 69,
    };
  }
  return 99;
}

/// Gom các dòng thành nhóm, nhóm mới nhất trước.
List<HistoryGroup> groupHistory(Iterable<HistoryEntry> entries) {
  final byKey = <String, List<HistoryEntry>>{};
  for (final entry in entries) {
    byKey.putIfAbsent(entry.groupKey, () => <HistoryEntry>[]).add(entry);
  }

  final groups = <HistoryGroup>[
    for (final item in byKey.entries)
      HistoryGroup(
        key: item.key,
        entries: [...item.value]..sort((a, b) {
            final rank =
                historyDisplayRank(a).compareTo(historyDisplayRank(b));
            return rank != 0 ? rank : a.id.compareTo(b.id);
          }),
      ),
  ];

  groups.sort((a, b) {
    final time = b.createdAt.compareTo(a.createdAt);
    return time != 0 ? time : b.key.compareTo(a.key);
  });
  return groups;
}