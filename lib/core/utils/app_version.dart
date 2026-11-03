/// Ghép số phiên bản và số bản dựng thành chuỗi hiển thị, ví dụ
/// "Phiên bản 1.0.0 (1)".
String formatAppVersion({
  required String version,
  required String buildNumber,
}) {
  final cleanVersion = version.trim();
  final cleanBuild = buildNumber.trim();
  if (cleanVersion.isEmpty) {
    return 'Phiên bản không rõ';
  }
  if (cleanBuild.isEmpty) {
    return 'Phiên bản $cleanVersion';
  }
  return 'Phiên bản $cleanVersion ($cleanBuild)';
}