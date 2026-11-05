const Set<String> _allowedPlatforms = {'android', 'ios'};

/// Tạo dòng gửi lên bảng admin_devices.
/// Cột fcm_token chứa Firebase Installation ID (FID).
/// Cố ý KHÔNG có user_id: database tự điền bằng auth.uid(), và khi trùng
/// fcm_token thì dòng cũ giữ nguyên chủ.
/// Ném ArgumentError nếu fid rỗng hoặc platform không được database cho phép.
Map<String, dynamic> buildAdminDeviceRow({
  required String fid,
  required DateTime now,
  String platform = 'android',
}) {
  final cleanFid = fid.trim();
  if (cleanFid.isEmpty) {
    throw ArgumentError.value(fid, 'fid', 'FID không được rỗng');
  }
  if (!_allowedPlatforms.contains(platform)) {
    throw ArgumentError.value(platform, 'platform', 'Nền tảng không hợp lệ');
  }
  return <String, dynamic>{
    'fcm_token': cleanFid,
    'platform': platform,
    'last_seen_at': now.toUtc().toIso8601String(),
  };
}
