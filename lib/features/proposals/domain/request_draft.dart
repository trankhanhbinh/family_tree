// Giá trị cột entity_type / action của bảng change_requests.
const String kEntityPerson = 'person';
const String kEntityParentChild = 'parent_child';
const String kEntityMarriage = 'marriage';
const String kEntityPersonPhoto = 'person_photo';

const String kActionCreate = 'create';
const String kActionUpdate = 'update';
const String kActionDelete = 'delete';

/// Một đề xuất chưa gửi. Một lần gửi có thể gồm nhiều đề xuất
/// (người mới trước, quan hệ sau), gửi cùng một lệnh insert.
class RequestDraft {
  const RequestDraft({
    required this.entityType,
    required this.action,
    required this.payload,
    this.entityId,
  });

  final String entityType;
  final String action;
  final String? entityId;
  final Map<String, dynamic> payload;
}