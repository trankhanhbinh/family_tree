/// Một dòng của bảng change_requests.
class ChangeRequest {
  const ChangeRequest({
    required this.id,
    required this.requesterId,
    required this.nickname,
    required this.entityType,
    this.entityId,
    required this.action,
    required this.payload,
    this.note,
    required this.status,
    this.rejectReason,
    required this.createdAtRaw,
    required this.createdAt,
    this.reviewedAt,
  });

  factory ChangeRequest.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['created_at'] as String;
    final reviewedRaw = json['reviewed_at'] as String?;
    final payloadRaw = json['payload'];
    return ChangeRequest(
      id: json['id'] as String,
      requesterId: json['requester_id'] as String,
      nickname: json['nickname'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String?,
      action: json['action'] as String,
      payload: payloadRaw is Map
          ? Map<String, dynamic>.from(payloadRaw)
          : <String, dynamic>{},
      note: json['note'] as String?,
      status: json['status'] as String,
      rejectReason: json['reject_reason'] as String?,
      createdAtRaw: createdRaw,
      createdAt: DateTime.parse(createdRaw),
      reviewedAt: reviewedRaw == null ? null : DateTime.parse(reviewedRaw),
    );
  }

  final String id;
  final String requesterId;
  final String nickname;
  final String entityType;
  final String? entityId;
  final String action;
  final Map<String, dynamic> payload;
  final String? note;
  final String status;
  final String? rejectReason;

  /// Chuỗi thời gian gốc từ server (giữ nguyên độ chính xác micro giây,
  /// dùng làm khóa gom gói).
  final String createdAtRaw;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  /// Mọi dòng của MỘT lần gửi có cùng người gửi và cùng created_at
  /// (cột created_at mặc định now() = giờ bắt đầu giao dịch).
  String get bundleKey => '$requesterId|$createdAtRaw';
}

/// Các loại app có thể đọc hiểu và duyệt.
const List<String> kReviewableEntityTypes = [
  'person',
  'parent_child',
  'marriage',
];

/// Thứ tự áp dụng (giống hệt hàm SQL approve_change_bundle):
/// tạo chi/nhánh, tạo người, tạo quan hệ, sửa, rồi xóa quan hệ trước khi xóa người.
int approvalRank(String entityType, String action) {
  if (action == 'create') {
    return switch (entityType) {
      'branch' => 10,
      'person' => 20,
      'parent_child' => 30,
      'marriage' => 31,
      'person_photo' => 32,
      _ => 39,
    };
  }
  if (action == 'update') {
    return 50;
  }
  if (action == 'delete') {
    return switch (entityType) {
      'person_photo' => 60,
      'parent_child' => 61,
      'marriage' => 62,
      'person' => 70,
      'branch' => 80,
      _ => 89,
    };
  }
  return 99;
}

/// Một "gói" đề xuất: các dòng của cùng một lần gửi, đã xếp theo thứ tự duyệt.
class ReviewBundle {
  const ReviewBundle({required this.key, required this.requests});

  final String key;
  final List<ChangeRequest> requests;

  String get nickname => requests.first.nickname;

  DateTime get createdAt => requests.first.createdAt;

  List<String> get requestIds => [for (final r in requests) r.id];

  /// Ghi chú đầu tiên không rỗng (ghi chú chỉ gắn vào một dòng của gói).
  String? get note {
    for (final r in requests) {
      final text = r.note?.trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  String? get rejectReason {
    for (final r in requests) {
      final text = r.rejectReason?.trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  String get status => requests.first.status;

  bool get isPending => status == 'pending';

  DateTime? get reviewedAt => requests.first.reviewedAt;

  /// Có dòng app chưa hỗ trợ duyệt (ví dụ ảnh).
  bool get hasUnsupported => requests.any(
        (r) => !kReviewableEntityTypes.contains(r.entityType),
      );

  String get statusLabel {
    return switch (status) {
      'approved' => 'Đã duyệt',
      'rejected' => 'Đã từ chối',
      _ => 'Chờ duyệt',
    };
  }
}

/// Gom các dòng thành gói. Trong gói xếp theo thứ tự duyệt.
/// Danh sách gói: cũ nhất trước ([oldestFirst] = true) hoặc mới nhất trước.
List<ReviewBundle> groupRequests(
  Iterable<ChangeRequest> requests, {
  bool oldestFirst = true,
}) {
  final byKey = <String, List<ChangeRequest>>{};
  for (final r in requests) {
    byKey.putIfAbsent(r.bundleKey, () => <ChangeRequest>[]).add(r);
  }

  final bundles = <ReviewBundle>[
    for (final entry in byKey.entries)
      ReviewBundle(
        key: entry.key,
        requests: [...entry.value]..sort((a, b) {
            final rank = approvalRank(a.entityType, a.action)
                .compareTo(approvalRank(b.entityType, b.action));
            return rank != 0 ? rank : a.id.compareTo(b.id);
          }),
      ),
  ];

  bundles.sort(
    (a, b) => oldestFirst
        ? a.createdAt.compareTo(b.createdAt)
        : b.createdAt.compareTo(a.createdAt),
  );
  return bundles;
}