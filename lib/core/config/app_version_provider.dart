import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:familytree/core/utils/app_version.dart';

/// Chuỗi phiên bản của app đang chạy, đọc từ hệ thống (khớp pubspec.yaml).
final appVersionTextProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return formatAppVersion(
    version: info.version,
    buildNumber: info.buildNumber,
  );
});