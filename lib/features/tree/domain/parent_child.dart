enum RelationType {
  biological,
  adopted,
  step;

  static RelationType fromString(String? value) => switch (value) {
        'adopted' => RelationType.adopted,
        'step' => RelationType.step,
        _ => RelationType.biological,
      };
}

class ParentChild {
  const ParentChild({
    required this.id,
    required this.parentId,
    required this.childId,
    required this.relationType,
  });

  final String id;
  final String parentId;
  final String childId;
  final RelationType relationType;

  factory ParentChild.fromJson(Map<String, dynamic> json) {
    return ParentChild(
      id: json['id'] as String,
      parentId: json['parent_id'] as String,
      childId: json['child_id'] as String,
      relationType: RelationType.fromString(json['relation_type'] as String?),
    );
  }
}