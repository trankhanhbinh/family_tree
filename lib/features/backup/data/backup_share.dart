import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Mở bảng chia sẻ của điện thoại với file JSON tạo từ dữ liệu trong bộ nhớ.
/// fileNameOverrides giữ đúng tên file (XFile.fromData bỏ qua tên trên Android).
Future<void> shareBackupFile({
  required String fileName,
  required String json,
}) async {
  final bytes = Uint8List.fromList(utf8.encode(json));
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'application/json')],
      fileNameOverrides: [fileName],
      subject: 'Sao lưu gia phả',
    ),
  );
}