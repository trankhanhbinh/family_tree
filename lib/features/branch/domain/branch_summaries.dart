import 'package:familytree/features/clan/domain/clan_info_form.dart'
    show normalizeOptionalText;
import 'package:familytree/features/tree/domain/branch.dart';

/// Nội dung hộp thoại xác nhận khi thêm chi.
String describeBranchCreate({
  required String name,
  required String? parentPath,
}) {
  final where = parentPath ?? 'Chi gốc (không thuộc chi nào)';
  return 'Thêm chi "${name.trim()}"\nThuộc: $where';
}

/// Các dòng "Nhãn: cũ → mới" khi đổi tên / mô tả, theo thứ tự cố định.
List<String> describeBranchRename({
  required Branch original,
  required Map<String, dynamic> payload,
}) {
  final lines = <String>[];
  if (payload.containsKey('name')) {
    lines.add(
      'Tên chi: ${_shorten(original.name)} → '
      '${_shorten(payload['name'] as String?)}',
    );
  }
  if (payload.containsKey('description')) {
    lines.add(
      'Mô tả: ${_shorten(original.description)} → '
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