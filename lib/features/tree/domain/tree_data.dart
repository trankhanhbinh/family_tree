import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/person/domain/person_photo.dart';
import 'package:familytree/features/tree/domain/branch.dart';
import 'package:familytree/features/tree/domain/marriage.dart';
import 'package:familytree/features/tree/domain/parent_child.dart';

/// Toàn bộ dữ liệu gia phả, tải một lần.
class TreeData {
  const TreeData({
    required this.people,
    required this.branches,
    required this.parentChildren,
    required this.marriages,
    required this.photos,
  });

  final List<Person> people;
  final List<Branch> branches;
  final List<ParentChild> parentChildren;
  final List<Marriage> marriages;
  final List<PersonPhoto> photos;
}