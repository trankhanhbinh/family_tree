import 'package:familytree/core/utils/date_format.dart';
import 'package:familytree/features/person/domain/branch_path.dart';
import 'package:familytree/features/tree/domain/branch.dart';

const Map<String, String> kHistoryPersonLabels = {
  'full_name': 'Họ và tên',
  'other_name': 'Tên khác',
  'gender': 'Giới tính',
  'branch_id': 'Chi/nhánh',
  'generation': 'Số đời',
  'birth_date': 'Ngày sinh',
  'birth_year': 'Năm sinh',
  'birth_place': 'Nơi sinh',
  'is_alive': 'Tình trạng',
  'death_date': 'Ngày mất',
  'death_year': 'Năm mất',
  'burial_place': 'Nơi an táng',
  'memorial_lunar_day': 'Ngày giỗ (âm lịch)',
  'memorial_lunar_month': 'Tháng giỗ (âm lịch)',
  'memorial_is_leap': 'Tháng nhuận',
  'notes': 'Ghi chú',
};

const Map<String, String> kHistoryMarriageLabels = {
  'status': 'Tình trạng',
  'start_date': 'Ngày bắt đầu',
  'end_date': 'Ngày kết thúc',
  'notes': 'Ghi chú',
};

const Map<String, String> kHistoryPhotoLabels = {
  'caption': 'Mô tả',
  'is_avatar': 'Ảnh đại diện',
  'sort_order': 'Thứ tự',
};

/// Giá trị một cột dưới dạng chữ tiếng Việt.
String displayHistoryValue(
  String column,
  Object? value,
  List<Branch> branches,
) {
  if (value == null) {
    return column == 'branch_id' ? 'Không thuộc chi nào' : '(trống)';
  }
  switch (column) {
    case 'gender':
      return _genderLabel(value.toString());
    case 'is_alive':
      return value == true ? 'Còn sống' : 'Đã mất';
    case 'memorial_is_leap':
    case 'is_avatar':
      return value == true ? 'Có' : 'Không';
    case 'branch_id':
      return branchPathOf(value.toString(), branches) ?? 'Không rõ';
    case 'birth_date':
    case 'death_date':
    case 'start_date':
    case 'end_date':
      return _dateText(value);
    case 'status':
      return _marriageStatusLabel(value.toString());
    default:
      final text = value.toString().trim();
      return text.isEmpty ? '(trống)' : text;
  }
}

/// Mỗi cột đổi là một dòng "Nhãn: cũ → mới". Bỏ qua cột không đổi
/// và mọi cột không có trong [labels] (ví dụ updated_at).
List<String> diffHistoryLines({
  required Map<String, dynamic>? before,
  required Map<String, dynamic>? after,
  required Map<String, String> labels,
  required List<Branch> branches,
}) {
  final lines = <String>[];
  for (final entry in labels.entries) {
    final column = entry.key;
    final oldText = displayHistoryValue(column, before?[column], branches);
    final newText = displayHistoryValue(column, after?[column], branches);
    if (oldText == newText) {
      continue;
    }
    lines.add('${entry.value}: $oldText → $newText');
  }
  return lines;
}

/// Các dòng "Nhãn: giá trị" cho dữ liệu mới tạo. Bỏ qua giá trị trống
/// và các giá trị mặc định (còn sống, không nhuận).
List<String> filledHistoryLines({
  required Map<String, dynamic>? data,
  required Map<String, String> labels,
  required List<Branch> branches,
  Set<String> skip = const {},
}) {
  final lines = <String>[];
  for (final entry in labels.entries) {
    final column = entry.key;
    if (skip.contains(column)) {
      continue;
    }
    final value = data?[column];
    if (value == null) {
      continue;
    }
    if (value is String && value.trim().isEmpty) {
      continue;
    }
    if (column == 'memorial_is_leap' && value == false) {
      continue;
    }
    if (column == 'is_alive' && value == true) {
      continue;
    }
    lines.add('${entry.value}: ${displayHistoryValue(column, value, branches)}');
  }
  return lines;
}

String _genderLabel(String value) {
  return switch (value) {
    'male' => 'Nam',
    'female' => 'Nữ',
    'other' => 'Khác',
    _ => value,
  };
}

String _marriageStatusLabel(String value) {
  return switch (value) {
    'married' => 'Đang kết hôn',
    'divorced' => 'Đã ly hôn',
    'widowed' => 'Đã góa',
    _ => value,
  };
}

String _dateText(Object? value) {
  DateTime? date;
  if (value is DateTime) {
    date = value;
  } else if (value is String) {
    date = DateTime.tryParse(value);
  }
  if (date == null) {
    return value?.toString() ?? '';
  }
  return formatDate(date);
}