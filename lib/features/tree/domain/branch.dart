class Branch {
  const Branch({
    required this.id,
    required this.name,
    this.description,
    this.parentBranchId,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final String? description;
  final String? parentBranchId;
  final int sortOrder;

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      parentBranchId: json['parent_branch_id'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}