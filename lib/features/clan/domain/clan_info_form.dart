import 'package:familytree/features/clan/domain/clan_info.dart';

const int kClanNameMaxLength = 100;
const int kClanOriginMaxLength = 500;
const int kClanDescriptionMaxLength = 2000;

/// Trả về câu báo lỗi tiếng Việt, hoặc null nếu tên hợp lệ.
String? validateClanName(String raw) {
  final name = raw.trim();
  if (name.isEmpty) {
    return 'Hãy nhập tên dòng họ.';
  }
  if (name.length > kClanNameMaxLength) {
    return 'Tên dòng họ tối đa $kClanNameMaxLength ký tự.';
  }
  return null;
}

/// Bỏ khoảng trắng hai đầu; rỗng thì trả null.
String? normalizeOptionalText(String? raw) {
  final text = raw?.trim() ?? '';
  return text.isEmpty ? null : text;
}

/// Chỉ chứa các cột THỰC SỰ đổi (name, origin, description).
/// Ô không bắt buộc bị xóa trống thì giá trị là null.
/// Rỗng = không có gì thay đổi.
Map<String, dynamic> buildClanInfoUpdatePayload({
  required ClanInfo original,
  required String name,
  required String origin,
  required String description,
}) {
  final payload = <String, dynamic>{};

  final newName = name.trim();
  if (newName != original.name.trim()) {
    payload['name'] = newName;
  }

  final newOrigin = normalizeOptionalText(origin);
  if (newOrigin != normalizeOptionalText(original.origin)) {
    payload['origin'] = newOrigin;
  }

  final newDescription = normalizeOptionalText(description);
  if (newDescription != normalizeOptionalText(original.description)) {
    payload['description'] = newDescription;
  }

  return payload;
}

/// Các dòng "Nhãn: cũ → mới" cho hộp thoại xác nhận, theo thứ tự cố định.
List<String> describeClanChanges({
  required ClanInfo original,
  required Map<String, dynamic> payload,
}) {
  final lines = <String>[];

  if (payload.containsKey('name')) {
    lines.add(
      'Tên dòng họ: ${_shorten(original.name)} → '
      '${_shorten(payload['name'] as String?)}',
    );
  }
  if (payload.containsKey('origin')) {
    lines.add(
      'Nguồn gốc: ${_shorten(original.origin)} → '
      '${_shorten(payload['origin'] as String?)}',
    );
  }
  if (payload.containsKey('description')) {
    lines.add(
      'Giới thiệu: ${_shorten(original.description)} → '
      '${_shorten(payload['description'] as String?)}',
    );
  }
  return lines;
}

String _shorten(String? raw) {
  final text = normalizeOptionalText(raw);
  if (text == null) {
    return '(trống)';
  }
  if (text.length > 60) {
    return '${text.substring(0, 60)}…';
  }
  return text;
}