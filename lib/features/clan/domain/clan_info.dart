/// Thông tin dòng họ (bảng clan_info, chỉ có 1 dòng id = 1).
class ClanInfo {
  const ClanInfo({
    required this.name,
    this.origin,
    this.description,
  });

  final String name;
  final String? origin;
  final String? description;

  factory ClanInfo.fromJson(Map<String, dynamic> json) {
    return ClanInfo(
      name: json['name'] as String,
      origin: json['origin'] as String?,
      description: json['description'] as String?,
    );
  }
}