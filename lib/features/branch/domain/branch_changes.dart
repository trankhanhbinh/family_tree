import 'package:familytree/features/clan/domain/clan_info_form.dart'
    show normalizeOptionalText;
import 'package:familytree/features/tree/domain/branch.dart';

/// Payload tạo chi mới (entity "branch", action "create").
Map<String, dynamic> buildBranchCreatePayload({
  required String name,
  required String description,
  required String? parentBranchId,
  required int sortOrder,
}) {
  return {
    'name': name.trim(),
    'description': normalizeOptionalText(description),
    'parent_branch_id': parentBranchId,
    'sort_order': sortOrder,
  };
}

/// Payload đổi tên / mô tả: chỉ chứa cột THỰC SỰ đổi. Rỗng = không đổi gì.
Map<String, dynamic> buildBranchRenamePayload({
  required Branch original,
  required String name,
  required String description,
}) {
  final payload = <String, dynamic>{};

  final newName = name.trim();
  if (newName != original.name.trim()) {
    payload['name'] = newName;
  }

  final newDescription = normalizeOptionalText(description);
  if (newDescription != normalizeOptionalText(original.description)) {
    payload['description'] = newDescription;
  }
  return payload;
}

/// Payload chuyển chi sang chi cha khác (null = chi gốc).
Map<String, dynamic> buildBranchMovePayload({
  required String? newParentId,
  required int newSortOrder,
}) {
  return {
    'parent_branch_id': newParentId,
    'sort_order': newSortOrder,
  };
}

/// Payload đổi chi của một người (entity "person", action "update").
/// newBranchId = null nghĩa là bỏ người đó khỏi mọi chi.
Map<String, dynamic> buildPersonBranchPayload({required String? newBranchId}) {
  return {'branch_id': newBranchId};
}