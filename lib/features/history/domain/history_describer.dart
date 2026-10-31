import 'package:familytree/features/history/domain/field_display.dart';
import 'package:familytree/features/history/domain/history_entry.dart';
import 'package:familytree/features/tree/domain/branch.dart';
import 'package:familytree/features/tree/domain/tree_data.dart';

/// Tra tên người theo id. Trả về null nếu không biết.
typedef HistoryNameLookup = String? Function(Object? personId);

/// Một dòng lịch sử đã được đọc hiểu.
class DescribedHistoryEntry {
  const DescribedHistoryEntry({
    required this.title,
    this.details = const [],
  });

  final String title;
  final List<String> details;
}

const String _kUnknownName = '(không rõ)';

/// Tra tên: tên trong cây hiện tại được ưu tiên (tên mới nhất);
/// người đã xóa (không còn trên cây) lấy tên từ before/after của lịch sử.
HistoryNameLookup buildHistoryNameLookup({
  required TreeData tree,
  required Iterable<HistoryEntry> entries,
}) {
  final names = <String, String>{};
  for (final entry in entries) {
    if (entry.entityType != 'person') {
      continue;
    }
    final name = entry.data?['full_name'];
    if (name is String && name.trim().isNotEmpty) {
      names.putIfAbsent(entry.entityId, () => name);
    }
  }
  for (final person in tree.people) {
    names[person.id] = person.fullName;
  }
  return (Object? id) => id is String ? names[id] : null;
}

/// Danh sách chi để dựng đường dẫn trong lịch sử: chi trong cây hiện tại
/// (ưu tiên) cộng thêm chi đã xóa, dựng từ before/after của lịch sử
/// (dòng mới nhất của mỗi chi). Chi đã xóa chỉ cần id, tên, chi cha.
List<Branch> buildHistoryBranches({
  required TreeData tree,
  required Iterable<HistoryEntry> entries,
}) {
  final inTree = {for (final branch in tree.branches) branch.id};
  final fromHistory = <String, Branch>{};
  for (final entry in entries) {
    if (entry.entityType != 'branch') {
      continue;
    }
    if (inTree.contains(entry.entityId) ||
        fromHistory.containsKey(entry.entityId)) {
      continue;
    }
    final data = entry.data;
    final name = data?['name'];
    if (name is! String || name.trim().isEmpty) {
      continue;
    }
    final parent = data?['parent_branch_id'];
    fromHistory[entry.entityId] = Branch(
      id: entry.entityId,
      name: name,
      parentBranchId: parent is String ? parent : null,
      sortOrder: 0,
    );
  }
  if (fromHistory.isEmpty) {
    return tree.branches;
  }
  return [...tree.branches, ...fromHistory.values];
}

DescribedHistoryEntry describeHistoryEntry(
  HistoryEntry entry, {
  required HistoryNameLookup nameOf,
  required List<Branch> branches,
}) {
  switch (entry.entityType) {
    case 'person':
      return _describePerson(entry, branches);
    case 'parent_child':
      return _describeParentChild(entry, nameOf);
    case 'marriage':
      return _describeMarriage(entry, nameOf, branches);
    case 'person_photo':
      return _describePhoto(entry, nameOf);
    case 'branch':
      return _describeBranch(entry, branches);
    case 'clan_info':
      return _describeClan(entry);
    default:
      return DescribedHistoryEntry(
        title: 'Thay đổi khác (${entry.entityType}, ${entry.action})',
      );
  }
}

String _nameOrUnknown(HistoryNameLookup nameOf, Object? id) {
  return nameOf(id) ?? _kUnknownName;
}

String? _textOf(Object? value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

// ---------- Người ----------

DescribedHistoryEntry _describePerson(
  HistoryEntry entry,
  List<Branch> branches,
) {
  final name = _textOf(entry.data?['full_name']) ?? _kUnknownName;

  switch (entry.action) {
    case 'create':
      return DescribedHistoryEntry(
        title: 'Thêm người: $name',
        details: filledHistoryLines(
          data: entry.after,
          labels: kHistoryPersonLabels,
          branches: branches,
          skip: const {'full_name'},
        ),
      );
    case 'update':
      return DescribedHistoryEntry(
        title: 'Sửa thông tin: $name',
        details: diffHistoryLines(
          before: entry.before,
          after: entry.after,
          labels: kHistoryPersonLabels,
          branches: branches,
        ),
      );
    case 'restore':
      return DescribedHistoryEntry(
        title: 'Khôi phục người: $name',
        details: const ['Người này đã được đưa trở lại gia phả.'],
      );
    default:
      return DescribedHistoryEntry(
        title: 'Xóa người: $name',
        details: const ['Người này đã bị xóa khỏi gia phả.'],
      );
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

DescribedHistoryEntry _describeParentChild(
  HistoryEntry entry,
  HistoryNameLookup nameOf,
) {
  final data = entry.data;
  final parent = _nameOrUnknown(nameOf, data?['parent_id']);
  final child = _nameOrUnknown(nameOf, data?['child_id']);

  switch (entry.action) {
    case 'create':
      return DescribedHistoryEntry(
        title: 'Gắn $child là ${_relationName(data?['relation_type'])} '
            'của $parent',
      );
    case 'update':
      final oldType = _capitalize(_relationName(entry.before?['relation_type']));
      final newType = _capitalize(_relationName(entry.after?['relation_type']));
      return DescribedHistoryEntry(
        title: 'Đổi loại quan hệ: $child',
        details: ['Cha/mẹ: $parent', 'Loại quan hệ: $oldType → $newType'],
      );
    default:
      return DescribedHistoryEntry(
        title: 'Gỡ quan hệ: $parent là cha/mẹ của $child',
      );
  }
}

// ---------- Hôn nhân ----------

DescribedHistoryEntry _describeMarriage(
  HistoryEntry entry,
  HistoryNameLookup nameOf,
  List<Branch> branches,
) {
  final data = entry.data;
  final first = _nameOrUnknown(nameOf, data?['person1_id']);
  final second = _nameOrUnknown(nameOf, data?['person2_id']);
  final pair = '$first và $second';

  switch (entry.action) {
    case 'create':
      return DescribedHistoryEntry(
        title: 'Thêm hôn nhân: $pair',
        details: filledHistoryLines(
          data: entry.after,
          labels: kHistoryMarriageLabels,
          branches: branches,
        ),
      );
    case 'update':
      return DescribedHistoryEntry(
        title: 'Sửa hôn nhân: $pair',
        details: diffHistoryLines(
          before: entry.before,
          after: entry.after,
          labels: kHistoryMarriageLabels,
          branches: branches,
        ),
      );
    default:
      return DescribedHistoryEntry(title: 'Gỡ hôn nhân: $pair');
  }
}

// ---------- Ảnh ----------

DescribedHistoryEntry _describePhoto(
  HistoryEntry entry,
  HistoryNameLookup nameOf,
) {
  final data = entry.data;
  final person = _nameOrUnknown(nameOf, data?['person_id']);

  switch (entry.action) {
    case 'create':
      final caption = _textOf(data?['caption']);
      return DescribedHistoryEntry(
        title: 'Thêm ảnh cho $person',
        details: [if (caption != null) 'Mô tả: $caption'],
      );
    case 'update':
      return DescribedHistoryEntry(
        title: 'Sửa thông tin ảnh của $person',
        details: diffHistoryLines(
          before: entry.before,
          after: entry.after,
          labels: kHistoryPhotoLabels,
          branches: const [],
        ),
      );
    default:
      return DescribedHistoryEntry(title: 'Xóa một ảnh của $person');
  }
}

// ---------- Chi/nhánh ----------

bool _changed(HistoryEntry entry, String column) {
  return entry.before?[column] != entry.after?[column];
}

DescribedHistoryEntry _describeBranch(
  HistoryEntry entry,
  List<Branch> branches,
) {
  final name = _textOf(entry.data?['name']) ?? _kUnknownName;

  switch (entry.action) {
    case 'create':
      return DescribedHistoryEntry(
        title: 'Thêm chi: $name',
        details: filledHistoryLines(
          data: entry.after,
          labels: kHistoryBranchLabels,
          branches: branches,
          skip: const {'name'},
        ),
      );
    case 'update':
      final nameChanged = _changed(entry, 'name');
      final parentChanged = _changed(entry, 'parent_branch_id');
      final descriptionChanged = _changed(entry, 'description');
      final String title;
      if (nameChanged && !parentChanged && !descriptionChanged) {
        title = 'Đổi tên chi: $name';
      } else if (parentChanged && !nameChanged && !descriptionChanged) {
        title = 'Chuyển chi: $name';
      } else {
        title = 'Sửa chi: $name';
      }
      return DescribedHistoryEntry(
        title: title,
        details: diffHistoryLines(
          before: entry.before,
          after: entry.after,
          labels: kHistoryBranchLabels,
          branches: branches,
        ),
      );
    default:
      return DescribedHistoryEntry(
        title: 'Xóa chi: $name',
        details: const ['Chi này đã bị xóa khỏi gia phả.'],
      );
  }
}

// ---------- Thông tin dòng họ ----------

DescribedHistoryEntry _describeClan(HistoryEntry entry) {
  return DescribedHistoryEntry(
    title: 'Sửa thông tin dòng họ',
    details: diffHistoryLines(
      before: entry.before,
      after: entry.after,
      labels: kHistoryClanLabels,
      branches: const [],
    ),
  );
}