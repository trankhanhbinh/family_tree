import 'package:familytree/features/person/domain/person_photo.dart';
import 'package:familytree/features/proposals/domain/request_draft.dart';

/// Thêm một dòng ảnh. Ảnh đầu tiên của một người tự thành ảnh đại diện.
List<RequestDraft> planAddPhoto({
  required String photoId,
  required String personId,
  required String storagePath,
  required String caption,
  required int sortOrder,
  required bool makeAvatar,
}) {
  final text = caption.trim();
  return [
    RequestDraft(
      entityType: kEntityPersonPhoto,
      action: kActionCreate,
      payload: {
        'id': photoId,
        'person_id': personId,
        'storage_path': storagePath,
        'caption': ?(text.isEmpty ? null : text),
        'is_avatar': makeAvatar,
        'sort_order': sortOrder,
      },
    ),
  ];
}

/// Đặt ảnh đại diện: bỏ cờ ở ảnh cũ TRƯỚC, rồi đặt cờ ở ảnh mới
/// (database chỉ cho một ảnh đại diện mỗi người).
/// Ảnh đã là ảnh đại diện thì không có gì để làm (danh sách rỗng).
List<RequestDraft> planSetAvatar({
  required PersonPhoto photo,
  PersonPhoto? currentAvatar,
}) {
  if (photo.isAvatar) {
    return const [];
  }
  return [
    if (currentAvatar != null && currentAvatar.id != photo.id)
      RequestDraft(
        entityType: kEntityPersonPhoto,
        action: kActionUpdate,
        entityId: currentAvatar.id,
        payload: const {'is_avatar': false},
      ),
    RequestDraft(
      entityType: kEntityPersonPhoto,
      action: kActionUpdate,
      entityId: photo.id,
      payload: const {'is_avatar': true},
    ),
  ];
}

/// Xóa dòng ảnh (file trong bucket được dọn ở giai đoạn 5).
List<RequestDraft> planDeletePhoto(PersonPhoto photo) {
  return [
    RequestDraft(
      entityType: kEntityPersonPhoto,
      action: kActionDelete,
      entityId: photo.id,
      payload: const <String, dynamic>{},
    ),
  ];
}