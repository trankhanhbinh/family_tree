import 'package:familytree/features/person/domain/branch_path.dart';
import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/review/domain/change_request.dart';
import 'package:familytree/features/tree/domain/tree_data.dart';

const String _kMissingWarning =
    'Mục này không còn trong gia phả (có thể đã bị xóa).';
const String _kMissingPersonWarning =
    'Có người trong đề xuất này không còn trong gia phả.';

/// Một đề xuất đã được "đọc hiểu" để hiện cho người xem.
class DescribedRequest {
  const DescribedRequest({
    required this.title,
    this.details = const [],
    this.warning,
    this.supported = true,
  });

  final String title;
  final List<String> details;

  /// Cảnh báo (màu cam), ví dụ mục bị sửa/xóa không còn trên cây.
  /// Chỉ có với gói ĐANG CHỜ duyệt.
  final String? warning;

  /// false = app chưa hỗ trợ duyệt loại này (ví dụ ảnh).
  final bool supported;
}

/// Giờ địa phương dạng 28/10/2026 10:15.
String formatDateTime(DateTime value) {
  final local = value.toLocal();
  return '${_two(local.day)}/${_two(local.month)}/${local.year} '
      '${_two(local.hour)}:${_two(local.minute)}';
}

/// Cách đọc hiểu tùy trạng thái của gói:
/// - pending: so "cũ → mới" với cây hiện tại, có cảnh báo mục lỗi thời.
/// - rejected: so "cũ → mới" (cây không đổi), không cảnh báo.
/// - approved: thay đổi đã được áp dụng vào cây, nên chỉ hiện giá trị mới.
class _Mode {
  const _Mode({required this.pending, required this.applied});

  final bool pending;
  final bool applied;
}

/// Đọc hiểu cả gói, giữ đúng thứ tự của bundle.requests.
List<DescribedRequest> describeBundle(ReviewBundle bundle, TreeData tree) {
  final names = _NameBook(bundle, tree);
  final mode = _Mode(
    pending: bundle.isPending,
    applied: bundle.status == 'approved',
  );
  return [
    for (final request in bundle.requests)
      _describe(request, tree, names, mode),
  ];
}

// ---------- Tra tên người (kể cả người MỚI trong cùng gói) ----------

class _NameBook {
  _NameBook(ReviewBundle bundle, this._tree) {
    for (final r in bundle.requests) {
      if (r.entityType == 'person' && r.action == 'create') {
        final id = r.payload['id'];
        final name = r.payload['full_name'];
        if (id is String && name is String) {
          _created[id] = name;
        }
      }
    }
  }

  final TreeData _tree;
  final Map<String, String> _created = {};

  String? nameOf(Object? id) {
    if (id is! String) {
      return null;
    }
    final created = _created[id];
    if (created != null) {
      return created;
    }
    return _tree.people.where((p) => p.id == id).firstOrNull?.fullName;
  }
}

// ---------- Điều phối ----------

DescribedRequest _describe(
  ChangeRequest r,
  TreeData tree,
  _NameBook names,
  _Mode mode,
) {
  final described = _describeCore(r, tree, names, mode);
  if (mode.pending || described.warning == null) {
    return described;
  }
  // Gói đã xử lý: cảnh báo "mục lỗi thời" không còn ý nghĩa.
  return DescribedRequest(
    title: described.title,
    details: described.details,
    supported: described.supported,
  );
}

DescribedRequest _describeCore(
  ChangeRequest r,
  TreeData tree,
  _NameBook names,
  _Mode mode,
) {
  if (!kReviewableEntityTypes.contains(r.entityType)) {
    return DescribedRequest(title: _unsupportedTitle(r), supported: false);
  }
  if (r.action != 'create' && r.action != 'update' && r.action != 'delete') {
    return DescribedRequest(
      title: 'Thao tác không rõ (${r.action}) - chưa hỗ trợ duyệt trong app',
      supported: false,
    );
  }
  switch (r.entityType) {
    case 'person':
      return _describePerson(r, tree, mode);
    case 'parent_child':
      return _describeParentChild(r, tree, names, mode);
    default:
      return _describeMarriage(r, tree, names, mode);
  }
}

String _unsupportedTitle(ChangeRequest r) {
  if (r.entityType == 'person_photo') {
    return 'Ảnh (chưa hỗ trợ duyệt trong app)';
  }
  return 'Thay đổi khác (${r.entityType}, ${r.action}) - '
      'chưa hỗ trợ duyệt trong app';
}

// ---------- Người ----------

const Map<String, String> _personLabels = {
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

DescribedRequest _describePerson(ChangeRequest r, TreeData tree, _Mode mode) {
  final person = tree.people.where((p) => p.id == r.entityId).firstOrNull;

  if (r.action == 'create') {
    final name = r.payload['full_name'];
    return DescribedRequest(
      title: 'Thêm người: ${name is String ? name : '?'}',
      details: _personCreateDetails(r.payload, tree),
    );
  }

  if (r.action == 'update') {
    return DescribedRequest(
      title: 'Sửa thông tin: '
          '${person?.fullName ?? '(người không còn trong gia phả)'}',
      details: _diffLines(
        r.payload,
        tree,
        _personLabels,
        (person == null || mode.applied)
            ? null
            : (column) => _personColumn(person, column),
      ),
      warning: person == null ? _kMissingWarning : null,
    );
  }

  // delete
  if (person != null) {
    return DescribedRequest(
      title: 'Xóa người: ${person.fullName}',
      details: const ['Người này sẽ bị xóa khỏi gia phả.'],
    );
  }
  if (mode.pending) {
    return const DescribedRequest(
      title: 'Xóa người: (người không còn trong gia phả)',
      warning: _kMissingWarning,
    );
  }
  return const DescribedRequest(title: 'Xóa một người khỏi gia phả');
}

List<String> _personCreateDetails(Map<String, dynamic> payload, TreeData tree) {
  final lines = <String>[];
  void add(String label, String? text) {
    if (text != null && text.isNotEmpty) {
      lines.add('$label: $text');
    }
  }

  final gender = payload['gender'];
  if (gender is String) {
    add('Giới tính', _genderLabel(gender));
  }

  final birthDate = payload['birth_date'];
  final birthYear = payload['birth_year'];
  if (birthDate != null) {
    add('Ngày sinh', _dateText(birthDate));
  } else if (birthYear != null) {
    add('Năm sinh', '$birthYear');
  }
  add('Nơi sinh', _textOf(payload['birth_place']));

  if (payload['is_alive'] == false) {
    final deathDate = payload['death_date'];
    final deathYear = payload['death_year'];
    final String? when;
    if (deathDate != null) {
      when = _dateText(deathDate);
    } else if (deathYear != null) {
      when = 'năm $deathYear';
    } else {
      when = null;
    }
    add('Tình trạng', when == null ? 'Đã mất' : 'Đã mất ($when)');
    add('Nơi an táng', _textOf(payload['burial_place']));
    final day = payload['memorial_lunar_day'];
    final month = payload['memorial_lunar_month'];
    if (day != null && month != null) {
      final leap = payload['memorial_is_leap'] == true ? ' (nhuận)' : '';
      add('Ngày giỗ (âm lịch)', '$day/$month$leap');
    }
  }

  final branchId = payload['branch_id'];
  if (branchId is String) {
    add('Chi/nhánh', branchPathOf(branchId, tree.branches) ?? 'Không rõ');
  }
  add('Số đời', _textOf(payload['generation']));
  add('Ghi chú', _textOf(payload['notes']));
  return lines;
}

Object? _personColumn(Person p, String column) {
  switch (column) {
    case 'full_name':
      return p.fullName;
    case 'other_name':
      return p.otherName;
    case 'gender':
      return p.gender.name;
    case 'branch_id':
      return p.branchId;
    case 'generation':
      {
        final Object? generation = p.generation;
        return generation;
      }
    case 'birth_date':
      return p.birthDate;
    case 'birth_year':
      return p.birthYear ?? p.birthDate?.year;
    case 'birth_place':
      return p.birthPlace;
    case 'is_alive':
      return p.isAlive;
    case 'death_date':
      return p.deathDate;
    case 'death_year':
      return p.deathYear ?? p.deathDate?.year;
    case 'burial_place':
      return p.burialPlace;
    case 'memorial_lunar_day':
      return p.memorialLunarDay;
    case 'memorial_lunar_month':
      return p.memorialLunarMonth;
    case 'memorial_is_leap':
      return p.memorialIsLeap;
    case 'notes':
      return p.notes;
    default:
      return null;
  }
}

// ---------- Cha mẹ - con ----------

const Map<String, String> _relationNames = {
  'biological': 'con ruột',
  'adopted': 'con nuôi',
  'step': 'con riêng',
};

String _relationName(Object? type) => _relationNames[type] ?? 'con';

String _capitalize(String text) {
  if (text.isEmpty) {
    return text;
  }
  return text[0].toUpperCase() + text.substring(1);
}

DescribedRequest _describeParentChild(
  ChangeRequest r,
  TreeData tree,
  _NameBook names,
  _Mode mode,
) {
  final link = tree.parentChildren.where((pc) => pc.id == r.entityId).firstOrNull;

  if (r.action == 'create') {
    final parent = names.nameOf(r.payload['parent_id']);
    final child = names.nameOf(r.payload['child_id']);
    return DescribedRequest(
      title: 'Gắn ${child ?? '?'} là '
          '${_relationName(r.payload['relation_type'])} của ${parent ?? '?'}',
      warning: (parent == null || child == null) ? _kMissingPersonWarning : null,
    );
  }

  final parent = link == null ? null : names.nameOf(link.parentId);
  final child = link == null ? null : names.nameOf(link.childId);

  if (r.action == 'update') {
    final newType = r.payload['relation_type'];
    final oldType = link?.relationType.name;
    final typeLine = mode.applied
        ? 'Loại quan hệ mới: ${_capitalize(_relationName(newType))}'
        : 'Loại quan hệ: ${_capitalize(_relationName(oldType))} → '
            '${_capitalize(_relationName(newType))}';
    return DescribedRequest(
      title: 'Đổi loại quan hệ: ${child ?? '?'}',
      details: ['Cha/mẹ: ${parent ?? '?'}', typeLine],
      warning: link == null ? _kMissingWarning : null,
    );
  }

  // delete
  if (link != null || mode.pending) {
    return DescribedRequest(
      title: 'Gỡ quan hệ: ${parent ?? '?'} là cha/mẹ của ${child ?? '?'}',
      warning: link == null ? _kMissingWarning : null,
    );
  }
  return const DescribedRequest(title: 'Gỡ một quan hệ cha mẹ - con');
}

// ---------- Hôn nhân ----------

const Map<String, String> _marriageLabels = {
  'status': 'Tình trạng',
  'start_date': 'Ngày bắt đầu',
  'end_date': 'Ngày kết thúc',
  'notes': 'Ghi chú',
};

DescribedRequest _describeMarriage(
  ChangeRequest r,
  TreeData tree,
  _NameBook names,
  _Mode mode,
) {
  if (r.action == 'create') {
    final n1 = names.nameOf(r.payload['person1_id']);
    final n2 = names.nameOf(r.payload['person2_id']);
    final lines = <String>[];
    final status = r.payload['status'];
    if (status is String) {
      lines.add('Tình trạng: ${_marriageStatusLabel(status)}');
    }
    final start = r.payload['start_date'];
    if (start != null) {
      lines.add('Bắt đầu: ${_dateText(start)}');
    }
    final end = r.payload['end_date'];
    if (end != null) {
      lines.add('Kết thúc: ${_dateText(end)}');
    }
    return DescribedRequest(
      title: 'Thêm hôn nhân: ${n1 ?? '?'} và ${n2 ?? '?'}',
      details: lines,
      warning: (n1 == null || n2 == null) ? _kMissingPersonWarning : null,
    );
  }

  final marriage = tree.marriages.where((m) => m.id == r.entityId).firstOrNull;
  final n1 = marriage == null ? null : names.nameOf(marriage.person1Id);
  final n2 = marriage == null ? null : names.nameOf(marriage.person2Id);
  final pair = '${n1 ?? '?'} và ${n2 ?? '?'}';

  if (r.action == 'update') {
    return DescribedRequest(
      title: 'Sửa hôn nhân: $pair',
      details: _diffLines(
        r.payload,
        tree,
        _marriageLabels,
        (marriage == null || mode.applied)
            ? null
            : (column) {
                switch (column) {
                  case 'status':
                    return marriage.status.name;
                  case 'start_date':
                    return marriage.startDate;
                  case 'end_date':
                    return marriage.endDate;
                  case 'notes':
                    return marriage.notes;
                  default:
                    return null;
                }
              },
      ),
      warning: marriage == null ? _kMissingWarning : null,
    );
  }

  // delete
  if (marriage != null || mode.pending) {
    return DescribedRequest(
      title: 'Gỡ hôn nhân: $pair',
      warning: marriage == null ? _kMissingWarning : null,
    );
  }
  return const DescribedRequest(title: 'Gỡ một hôn nhân');
}

// ---------- Hàm nhỏ dùng chung ----------

/// Mỗi mục đổi một dòng "Nhãn: cũ → mới". Bỏ qua mục giá trị không đổi.
/// [oldValueOf] = null (không biết giá trị cũ) thì chỉ hiện "Nhãn: mới".
List<String> _diffLines(
  Map<String, dynamic> payload,
  TreeData tree,
  Map<String, String> labels,
  Object? Function(String column)? oldValueOf,
) {
  final lines = <String>[];
  for (final entry in payload.entries) {
    final column = entry.key;
    final label = labels[column] ?? column;
    final newText = _display(column, entry.value, tree);
    if (oldValueOf == null) {
      lines.add('$label: $newText');
      continue;
    }
    final oldText = _display(column, oldValueOf(column), tree);
    if (oldText == newText) {
      continue;
    }
    lines.add('$label: $oldText → $newText');
  }
  return lines;
}

String _display(String column, Object? value, TreeData tree) {
  if (value == null) {
    return column == 'branch_id' ? 'Không thuộc chi nào' : '(trống)';
  }
  switch (column) {
    case 'gender':
      return _genderLabel(value.toString());
    case 'is_alive':
      return value == true ? 'Còn sống' : 'Đã mất';
    case 'memorial_is_leap':
      return value == true ? 'Có' : 'Không';
    case 'branch_id':
      return branchPathOf(value.toString(), tree.branches) ?? 'Không rõ';
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
  return '${_two(date.day)}/${_two(date.month)}/${date.year}';
}

String? _textOf(Object? value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String _two(int value) => value.toString().padLeft(2, '0');