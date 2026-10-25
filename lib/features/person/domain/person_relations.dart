import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/tree/domain/marriage.dart';
import 'package:familytree/features/tree/domain/parent_child.dart';

class ParentEntry {
  const ParentEntry({required this.person, required this.relation});

  final Person person;
  final RelationType relation;
}

class SpouseEntry {
  const SpouseEntry({required this.person, required this.marriage});

  final Person person;
  final Marriage marriage;
}

class ChildEntry {
  const ChildEntry({required this.person, required this.relation});

  final Person person;
  final RelationType relation;
}

/// Quan hệ gia đình trực tiếp của một người (cha mẹ, vợ/chồng, con).
/// Dart thuần, chỉ dùng dữ liệu phẳng đã tải sẵn.
class PersonRelations {
  const PersonRelations({
    required this.parents,
    required this.spouses,
    required this.children,
  });

  final List<ParentEntry> parents;
  final List<SpouseEntry> spouses;
  final List<ChildEntry> children;

  bool get isEmpty => parents.isEmpty && spouses.isEmpty && children.isEmpty;

  factory PersonRelations.of(
    String personId, {
    required Iterable<Person> people,
    required Iterable<ParentChild> parentChildren,
    required Iterable<Marriage> marriages,
  }) {
    final byId = {for (final p in people) p.id: p};

    final parents = <ParentEntry>[];
    final children = <ChildEntry>[];
    for (final pc in parentChildren) {
      if (pc.childId == personId) {
        final parent = byId[pc.parentId];
        if (parent != null) {
          parents.add(ParentEntry(person: parent, relation: pc.relationType));
        }
      }
      if (pc.parentId == personId) {
        final child = byId[pc.childId];
        if (child != null) {
          children.add(ChildEntry(person: child, relation: pc.relationType));
        }
      }
    }

    final spouses = <SpouseEntry>[];
    for (final m in marriages) {
      String? otherId;
      if (m.person1Id == personId) {
        otherId = m.person2Id;
      } else if (m.person2Id == personId) {
        otherId = m.person1Id;
      }
      if (otherId == null) {
        continue;
      }
      final other = byId[otherId];
      if (other != null) {
        spouses.add(SpouseEntry(person: other, marriage: m));
      }
    }

    // Cha mẹ: ruột/nuôi trước, kế sau; nam trước nữ.
    parents.sort((a, b) {
      final byRelation =
          _relationRank(a.relation).compareTo(_relationRank(b.relation));
      if (byRelation != 0) {
        return byRelation;
      }
      final byGender =
          _genderRank(a.person.gender).compareTo(_genderRank(b.person.gender));
      if (byGender != 0) {
        return byGender;
      }
      return a.person.id.compareTo(b.person.id);
    });

    // Vợ/chồng: theo ngày bắt đầu hôn nhân, thiếu ngày thì xếp sau.
    spouses.sort((a, b) {
      final byStart =
          _compareNullableDate(a.marriage.startDate, b.marriage.startDate);
      if (byStart != 0) {
        return byStart;
      }
      final byName = a.person.fullName.compareTo(b.person.fullName);
      if (byName != 0) {
        return byName;
      }
      return a.person.id.compareTo(b.person.id);
    });

    // Con: theo ngày/năm sinh, không rõ xếp cuối.
    children.sort((a, b) {
      final byBirth =
          _compareNullableDate(_birthKey(a.person), _birthKey(b.person));
      if (byBirth != 0) {
        return byBirth;
      }
      final byName = a.person.fullName.compareTo(b.person.fullName);
      if (byName != 0) {
        return byName;
      }
      return a.person.id.compareTo(b.person.id);
    });

    return PersonRelations(
      parents: parents,
      spouses: spouses,
      children: children,
    );
  }

  static int _relationRank(RelationType relation) =>
      relation == RelationType.step ? 1 : 0;

  static int _genderRank(Gender gender) {
    if (gender == Gender.male) {
      return 0;
    }
    if (gender == Gender.female) {
      return 1;
    }
    return 2;
  }

  static DateTime? _birthKey(Person person) {
    final date = person.birthDate;
    if (date != null) {
      return date;
    }
    final year = person.birthYear;
    return year == null ? null : DateTime(year);
  }

  static int _compareNullableDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) {
      return 0;
    }
    if (a == null) {
      return 1;
    }
    if (b == null) {
      return -1;
    }
    return a.compareTo(b);
  }
}