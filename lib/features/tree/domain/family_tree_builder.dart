import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/tree/domain/family_node.dart';
import 'package:familytree/features/tree/domain/marriage.dart';
import 'package:familytree/features/tree/domain/parent_child.dart';
import 'package:familytree/features/tree/domain/tree_data.dart';

/// Gom dữ liệu phẳng (people, parent_child, marriages) thành cây.
/// Dart thuần, không phụ thuộc giao diện.
class FamilyTreeBuilder {
  FamilyTreeBuilder._();

  static FamilyForest fromTreeData(TreeData data) => build(
        people: data.people,
        parentChildren: data.parentChildren,
        marriages: data.marriages,
      );

  static FamilyForest build({
    required List<Person> people,
    required List<ParentChild> parentChildren,
    required List<Marriage> marriages,
  }) {
    final warnings = <String>[];
    final byId = {for (final p in people) p.id: p};

    // 1. Cha mẹ của từng người (bỏ dòng hỏng, bỏ trùng).
    final rowsOf = <String, List<ParentChild>>{};
    final seenRows = <String>{};
    for (final pc in parentChildren) {
      if (!byId.containsKey(pc.parentId) || !byId.containsKey(pc.childId)) {
        warnings.add('parent_child tham chiếu người không tồn tại: '
            '${pc.parentId} -> ${pc.childId}');
        continue;
      }
      if (pc.parentId == pc.childId) {
        warnings.add('parent_child tự trỏ vào chính mình: ${pc.childId}');
        continue;
      }
      if (!seenRows.add('${pc.parentId}>${pc.childId}')) continue;
      (rowsOf[pc.childId] ??= []).add(pc);
    }

    // Cha mẹ "hiệu lực": ưu tiên ruột/nuôi, chỉ dùng step nếu không có gì khác.
    final parentIds = <String, List<String>>{};
    for (final entry in rowsOf.entries) {
      var chosen =
          entry.value.where((r) => r.relationType != RelationType.step).toList();
      if (chosen.isEmpty) chosen = List.of(entry.value);
      var ids = chosen.map((r) => r.parentId).toList()..sort();
      if (ids.length > 2) {
        warnings.add('Người ${entry.key} có hơn 2 cha/mẹ, chỉ dùng 2 người đầu.');
        ids = ids.sublist(0, 2);
      }
      parentIds[entry.key] = ids;
    }

    // 2. Các cặp: từ hôn nhân + cặp cùng làm cha mẹ một người (không có hôn nhân).
    final pairs = <String, _Pair>{};
    for (final m in marriages) {
      if (m.person1Id == m.person2Id ||
          !byId.containsKey(m.person1Id) ||
          !byId.containsKey(m.person2Id)) {
        warnings.add('Hôn nhân ${m.id} không hợp lệ, bỏ qua.');
        continue;
      }
      final key = _pairKey(m.person1Id, m.person2Id);
      final existing = pairs[key];
      if (existing == null) {
        pairs[key] = _Pair(key, m.person1Id, m.person2Id)..marriage = m;
      } else {
        warnings.add('Hai hôn nhân cùng một cặp ($key): chỉ dùng cái đầu tiên.');
      }
    }
    for (final ids in parentIds.values) {
      if (ids.length == 2) {
        final key = _pairKey(ids[0], ids[1]);
        pairs.putIfAbsent(key, () => _Pair(key, ids[0], ids[1]));
      }
    }

    // 3. Xác định người chính (anchor) và vợ/chồng ngoại họ cho từng cặp.
    final anchorIds = <String>{};
    final spouseIds = <String>{};
    for (final pair in pairs.values) {
      final a = byId[pair.aId]!;
      final b = byId[pair.bId]!;
      final aHas = parentIds.containsKey(a.id);
      final bHas = parentIds.containsKey(b.id);
      final Person anchor;
      if (aHas != bHas) {
        anchor = aHas ? a : b;
      } else {
        anchor = _compareAnchor(a, b) <= 0 ? a : b;
      }
      final spouse = anchor.id == a.id ? b : a;
      pair.anchorId = anchor.id;
      pair.spouseId = spouse.id;
      anchorIds.add(anchor.id);
      spouseIds.add(spouse.id);
    }
    for (final id in spouseIds.intersection(anchorIds)) {
      warnings.add('Người $id vừa là người chính vừa là vợ/chồng ngoại họ '
          'ở cặp khác: sẽ xuất hiện ở 2 nơi.');
    }
    final spouseOnly = spouseIds.difference(anchorIds);
    for (final id in spouseOnly) {
      if (parentIds.containsKey(id)) {
        warnings.add('Người $id có cha mẹ trong cây nhưng chỉ hiện như '
            'vợ/chồng (cả hai người trong cặp đều có cha mẹ).');
      }
    }

    // 4. Tạo nút cho mọi người không phải "chỉ là vợ/chồng".
    final nodes = <String, FamilyNode>{
      for (final p in people)
        if (!spouseOnly.contains(p.id)) p.id: FamilyNode(p),
    };

    // 5. Dựng các "bản nháp" đơn vị gia đình theo người chính.
    final draftsByAnchor = <String, List<_Draft>>{};
    final draftsBySpouse = <String, List<_Draft>>{};
    final draftByPairKey = <String, _Draft>{};
    for (final pair in pairs.values) {
      final draft = _Draft(spouse: byId[pair.spouseId], marriage: pair.marriage);
      draftByPairKey[pair.key] = draft;
      (draftsByAnchor[pair.anchorId] ??= []).add(draft);
      (draftsBySpouse[pair.spouseId] ??= []).add(draft);
    }
    final singleDrafts = <String, _Draft>{};

    // 6. Gắn từng người con vào đúng đơn vị gia đình của cha mẹ.
    for (final child in people) {
      final pids = parentIds[child.id];
      if (pids == null || pids.isEmpty) continue; // người gốc
      if (spouseOnly.contains(child.id)) continue; // đã hiện cạnh bạn đời
      _Draft? target;
      if (pids.length == 2) {
        target = draftByPairKey[_pairKey(pids[0], pids[1])];
      } else {
        final pid = pids.first;
        if (nodes.containsKey(pid)) {
          target = singleDrafts[pid];
          if (target == null) {
            target = _Draft(spouse: null, marriage: null);
            singleDrafts[pid] = target;
            (draftsByAnchor[pid] ??= []).add(target);
          }
        } else {
          final list = draftsBySpouse[pid];
          target = (list == null || list.isEmpty) ? null : list.first;
        }
      }
      if (target == null) {
        warnings.add('Không tìm được nơi gắn người ${child.id}.');
        continue;
      }
      target.kids.add(child);
    }

    // 7. Sắp xếp và hoàn thiện cây.
    for (final entry in draftsByAnchor.entries) {
      final node = nodes[entry.key]!;
      final drafts = entry.value..sort(_compareDrafts);
      for (final d in drafts) {
        d.kids.sort(_comparePeople);
        final group = UnionGroup(spouse: d.spouse, marriage: d.marriage);
        group.children.addAll(d.kids.map((k) => nodes[k.id]!));
        for (final k in d.kids) {
          group.childRelations[k.id] = _relationFor(rowsOf[k.id], entry.key);
        }
        node.unions.add(group);
      }
    }

    final roots = nodes.values
        .where((n) => !parentIds.containsKey(n.person.id))
        .toList()
      ..sort((a, b) => _comparePeople(a.person, b.person));

    // 8. Kiểm tra: nút không với tới được từ gốc, và đời lệch nhau.
    final visited = <String>{};
    void visit(FamilyNode node) {
      if (!visited.add(node.person.id)) return;
      for (final u in node.unions) {
        for (final c in u.children) {
          final pg = node.person.generation;
          final cg = c.person.generation;
          if (pg != null && cg != null && cg != pg + 1) {
            warnings.add('Đời lệch: ${node.person.fullName} (đời $pg) -> '
                '${c.person.fullName} (đời $cg).');
          }
          visit(c);
        }
      }
    }

    for (final r in roots) {
      visit(r);
    }
    for (final id in nodes.keys) {
      if (!visited.contains(id)) {
        warnings.add('Người $id không nối được tới gốc nào (có thể có vòng lặp).');
      }
    }

    final nodeOfPerson = <String, FamilyNode>{...nodes};
    for (final node in nodes.values) {
      for (final u in node.unions) {
        final s = u.spouse;
        if (s != null) nodeOfPerson.putIfAbsent(s.id, () => node);
      }
    }

    return FamilyForest(
      roots: roots,
      nodeOfPerson: nodeOfPerson,
      spouseOnlyIds: spouseOnly,
      warnings: warnings,
    );
  }
}

// ---------------------------------------------------------------------------
// Phần phụ trợ (private)
// ---------------------------------------------------------------------------

class _Pair {
  _Pair(this.key, this.aId, this.bId);

  final String key;
  final String aId;
  final String bId;
  Marriage? marriage;
  late String anchorId;
  late String spouseId;
}

class _Draft {
  _Draft({required this.spouse, required this.marriage});

  final Person? spouse;
  final Marriage? marriage;
  final List<Person> kids = [];

  /// Khóa sắp xếp: ngày bắt đầu hôn nhân; thiếu thì lấy ngày sinh sớm nhất của con.
  DateTime? sortKey() {
    final start = marriage?.startDate;
    if (start != null) return start;
    DateTime? earliest;
    for (final k in kids) {
      final key = _birthKey(k);
      if (key != null && (earliest == null || key.isBefore(earliest))) {
        earliest = key;
      }
    }
    return earliest;
  }
}

/// Loại quan hệ của con với người chính; không có thì mặc định ruột.
RelationType _relationFor(List<ParentChild>? rows, String anchorId) {
  if (rows == null || rows.isEmpty) return RelationType.biological;
  for (final r in rows) {
    if (r.parentId == anchorId) return r.relationType;
  }
  return rows.first.relationType;
}

String _pairKey(String a, String b) => a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';

DateTime? _birthKey(Person p) {
  final d = p.birthDate;
  if (d != null) return d;
  final y = p.birthYear;
  if (y != null) return DateTime(y);
  return null;
}

int _generationOf(Person p) {
  final Object? g = p.generation;
  return g is int ? g : 1 << 30;
}

int _genderRank(Person p) => p.gender == Gender.male ? 0 : 1;

/// Ai là người chính khi cả hai (hoặc không ai) có cha mẹ trong cây:
/// đời nhỏ hơn, rồi nam, rồi id.
int _compareAnchor(Person a, Person b) {
  final g = _generationOf(a).compareTo(_generationOf(b));
  if (g != 0) return g;
  final s = _genderRank(a).compareTo(_genderRank(b));
  if (s != 0) return s;
  return a.id.compareTo(b.id);
}

/// Anh em: ngày sinh -> năm sinh -> tên -> id; không rõ năm sinh xếp cuối.
int _comparePeople(Person a, Person b) {
  final ka = _birthKey(a);
  final kb = _birthKey(b);
  if (ka != null && kb != null) {
    final c = ka.compareTo(kb);
    if (c != 0) return c;
  } else if (ka != null) {
    return -1;
  } else if (kb != null) {
    return 1;
  }
  final n = a.fullName.compareTo(b.fullName);
  if (n != 0) return n;
  return a.id.compareTo(b.id);
}

/// Các đơn vị gia đình của một người: có bạn đời trước, con riêng (không bạn
/// đời) sau cùng; trong nhóm có bạn đời thì theo khóa ngày, thiếu thì xếp sau.
int _compareDrafts(_Draft a, _Draft b) {
  if ((a.spouse == null) != (b.spouse == null)) {
    return a.spouse == null ? 1 : -1;
  }
  final ka = a.sortKey();
  final kb = b.sortKey();
  if (ka != null && kb != null) {
    final c = ka.compareTo(kb);
    if (c != 0) return c;
  } else if (ka != null) {
    return -1;
  } else if (kb != null) {
    return 1;
  }
  return (a.spouse?.id ?? '').compareTo(b.spouse?.id ?? '');
}