import 'package:familytree/core/utils/vietnamese_text.dart';
import 'package:familytree/features/person/domain/person.dart';

/// Tìm người theo họ tên và tên khác, không phân biệt hoa thường và dấu.
/// Mọi từ trong [query] đều phải xuất hiện (không cần đúng thứ tự).
List<Person> searchPeople(List<Person> people, String query) {
  final q = normalizeVietnamese(query).trim();
  if (q.isEmpty) {
    return const [];
  }
  final tokens = q.split(RegExp(r'\s+'));

  final scored = <_Scored>[];
  for (final person in people) {
    final name = normalizeVietnamese(person.fullName);
    final other = normalizeVietnamese(person.otherName ?? '');
    final haystack = '$name $other';
    if (!tokens.every(haystack.contains)) {
      continue;
    }
    final int rank;
    if (name.startsWith(q)) {
      rank = 0;
    } else if (name.contains(q) || other.contains(q)) {
      rank = 1;
    } else {
      rank = 2;
    }
    scored.add(_Scored(person, rank, name));
  }

  scored.sort((a, b) {
    final byRank = a.rank.compareTo(b.rank);
    return byRank != 0 ? byRank : a.name.compareTo(b.name);
  });
  return scored.map((s) => s.person).toList();
}

class _Scored {
  _Scored(this.person, this.rank, this.name);

  final Person person;
  final int rank;
  final String name;
}