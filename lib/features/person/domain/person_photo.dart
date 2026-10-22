class PersonPhoto {
  const PersonPhoto({
    required this.id,
    required this.personId,
    required this.storagePath,
    this.caption,
    required this.isAvatar,
    required this.sortOrder,
  });

  final String id;
  final String personId;
  final String storagePath;
  final String? caption;
  final bool isAvatar;
  final int sortOrder;

  factory PersonPhoto.fromJson(Map<String, dynamic> json) {
    return PersonPhoto(
      id: json['id'] as String,
      personId: json['person_id'] as String,
      storagePath: json['storage_path'] as String,
      caption: json['caption'] as String?,
      isAvatar: json['is_avatar'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}