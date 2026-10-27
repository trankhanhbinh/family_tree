import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/person/domain/person_create.dart';
import 'package:familytree/features/person/domain/person_edit_form.dart';
import 'package:familytree/features/proposals/domain/request_draft.dart';
import 'package:familytree/features/tree/domain/marriage.dart';
import 'package:familytree/features/tree/domain/parent_child.dart';

const int kReasonMinLength = 3;

/// Kiểm tra lý do. Trả về câu báo lỗi tiếng Việt, hoặc null nếu hợp lệ.
String? validateReason(String input, {required bool required}) {
  final text = input.trim();
  if (text.isEmpty) {
    return required ? 'Vui lòng nhập lý do.' : null;
  }
  if (required && text.length < kReasonMinLength) {
    return 'Lý do quá ngắn, vui lòng nhập ít nhất $kReasonMinLength ký tự.';
  }
  if (text.length > kRequestNoteMaxLength) {
    return 'Lý do quá dài (tối đa $kRequestNoteMaxLength ký tự).';
  }
  return null;
}

RequestDraft _delete(String entityType, String id) {
  return RequestDraft(
    entityType: entityType,
    action: kActionDelete,
    entityId: id,
    payload: const <String, dynamic>{},
  );
}

/// Đổi loại quan hệ của MỌI dòng cha-con của đứa trẻ [childId].
/// Dòng đã đúng loại thì bỏ qua. Không có gì cần đổi thì trả về danh sách rỗng.
List<RequestDraft> planChangeRelationType({
  required String childId,
  required Iterable<ParentChild> parentChildren,
  required RelationType newType,
}) {
  return [
    for (final pc in parentChildren)
      if (pc.childId == childId && pc.relationType != newType)
        RequestDraft(
          entityType: kEntityParentChild,
          action: kActionUpdate,
          entityId: pc.id,
          payload: {'relation_type': newType.name},
        ),
  ];
}

/// Gỡ đúng một dòng cha-con.
List<RequestDraft> planRemoveParentChild(ParentChild link) {
  return [_delete(kEntityParentChild, link.id)];
}

/// Gỡ một dòng hôn nhân (không xóa người nào).
List<RequestDraft> planRemoveMarriage(Marriage marriage) {
  return [_delete(kEntityMarriage, marriage.id)];
}

/// Người này có làm cha/mẹ của ai không (còn con cháu).
bool personHasChildren(String personId, Iterable<ParentChild> parentChildren) {
  return parentChildren.any((pc) => pc.parentId == personId);
}

/// Gói đề xuất xóa người, theo thứ tự: các dòng cha-mẹ của người đó,
/// các dòng hôn nhân của người đó, rồi chính người đó.
/// (Hàm duyệt chỉ xóa mềm người mà KHÔNG dọn các dòng quan hệ.)
/// Ném ArgumentError nếu người này còn con.
List<RequestDraft> planDeletePerson({
  required Person person,
  required Iterable<ParentChild> parentChildren,
  required Iterable<Marriage> marriages,
}) {
  if (personHasChildren(person.id, parentChildren)) {
    throw ArgumentError('Người này còn con cháu nên chưa thể xóa.');
  }
  return [
    for (final pc in parentChildren)
      if (pc.childId == person.id) _delete(kEntityParentChild, pc.id),
    for (final m in marriages)
      if (m.person1Id == person.id || m.person2Id == person.id)
        _delete(kEntityMarriage, m.id),
    _delete(kEntityPerson, person.id),
  ];
}

/// Điền sẵn form hôn nhân từ dữ liệu hiện có.
MarriageFormValues marriageFormValuesOf(Marriage marriage) {
  final start = marriage.startDate;
  final end = marriage.endDate;
  return MarriageFormValues(
    status: marriage.status,
    startDay: start == null ? '' : '${start.day}',
    startMonth: start == null ? '' : '${start.month}',
    startYear: start == null ? '' : '${start.year}',
    endDay: end == null ? '' : '${end.day}',
    endMonth: end == null ? '' : '${end.month}',
    endYear: end == null ? '' : '${end.year}',
  );
}

/// Payload sửa hôn nhân: CHỈ gồm cột thực sự thay đổi.
/// Đổi sang "đang kết hôn" thì ngày kết thúc bị xóa (gửi null).
/// Ném ArgumentError nếu dữ liệu chưa hợp lệ.
Map<String, dynamic> buildMarriageUpdatePayload(
  Marriage original,
  MarriageFormValues values, {
  String notes = '',
  required int nowYear,
}) {
  final errors = validateMarriageForm(values, nowYear: nowYear);
  if (errors.isNotEmpty) {
    throw ArgumentError('Dữ liệu chưa hợp lệ: ${errors.values.join('; ')}');
  }

  final start = marriageDateOf(
    parseDateParts(
      day: values.startDay,
      month: values.startMonth,
      year: values.startYear,
      nowYear: nowYear,
    ),
  );
  final end = values.status == MarriageStatus.married
      ? null
      : marriageDateOf(
          parseDateParts(
            day: values.endDay,
            month: values.endMonth,
            year: values.endYear,
            nowYear: nowYear,
          ),
        );

  final payload = <String, dynamic>{};
  void put(String column, Object? before, Object? after) {
    if (before != after) {
      payload[column] = after;
    }
  }

  put('status', original.status.name, values.status.name);
  put('start_date', _isoDate(original.startDate), _isoDate(start));
  put('end_date', _isoDate(original.endDate), _isoDate(end));
  put('notes', _trimOrNull(original.notes), _trimOrNull(notes));
  return payload;
}

String? _trimOrNull(String? input) {
  final text = (input ?? '').trim();
  return text.isEmpty ? null : text;
}

String? _isoDate(DateTime? d) {
  if (d == null) {
    return null;
  }
  final yyyy = d.year.toString().padLeft(4, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd';
}