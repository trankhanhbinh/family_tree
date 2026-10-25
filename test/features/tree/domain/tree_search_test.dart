import 'package:familytree/core/utils/vietnamese_text.dart';
import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/tree/domain/family_node.dart';
import 'package:familytree/features/tree/domain/tree_search.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sample_family.dart';

List<Person> _allPeople(FamilyForest forest) {
  final result = <Person>[];
  void visit(FamilyNode node) {
    result.add(node.person);
    for (final union in node.unions) {
      final spouse = union.spouse;
      if (spouse != null) {
        result.add(spouse);
      }
      for (final child in union.children) {
        visit(child);
      }
    }
  }

  for (final root in forest.roots) {
    visit(root);
  }
  return result;
}

void main() {
  late List<Person> people;
  late Person p03;

  setUp(() {
    people = _allPeople(buildSampleForest());
    p03 = people.firstWhere((p) => p.id == '03');
  });

  test('đủ 16 người để tìm', () {
    expect(people.length, 16);
  });

  test('chuỗi rỗng hoặc toàn khoảng trắng: không có kết quả', () {
    expect(searchPeople(people, ''), isEmpty);
    expect(searchPeople(people, '   '), isEmpty);
  });

  test('gõ không dấu, chữ hoa vẫn tìm ra (người 03)', () {
    final last = p03.fullName.trim().split(RegExp(r'\s+')).last;
    final query = normalizeVietnamese(last).toUpperCase();
    final ids = searchPeople(people, query).map((p) => p.id);
    expect(ids, contains('03'));
  });

  test('nhiều từ không cần đúng thứ tự (người 03)', () {
    final words = p03.fullName.trim().split(RegExp(r'\s+')).reversed.join(' ');
    final ids = searchPeople(people, words).map((p) => p.id);
    expect(ids, contains('03'));
  });

  test('gõ đúng toàn bộ họ tên thì người đó đứng đầu', () {
    final results = searchPeople(people, p03.fullName);
    expect(results.first.id, '03');
  });

  test('không khớp thì rỗng', () {
    expect(searchPeople(people, 'zzzzqx'), isEmpty);
  });
}