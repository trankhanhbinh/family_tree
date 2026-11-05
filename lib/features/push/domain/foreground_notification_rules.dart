import 'package:familytree/features/push/domain/push_route_rules.dart';

/// Mã kênh thông báo Android. PHẢI khớp với giá trị
/// com.google.firebase.messaging.default_notification_channel_id trong
/// AndroidManifest.xml.
const String kRequestsChannelId = 'new_requests';
const String kRequestsChannelName = 'Đề xuất mới';
const String kRequestsChannelDescription =
    'Thông báo khi có đề xuất mới cần duyệt';

/// Tiêu đề dùng khi thông báo không kèm tiêu đề.
const String kDefaultNotificationTitle = 'Có đề xuất mới';

/// Nội dung đã chuẩn hóa để hiện thông báo cục bộ khi app đang mở.
class ForegroundNotificationContent {
  const ForegroundNotificationContent({
    required this.title,
    required this.body,
    required this.payload,
  });

  final String title;
  final String body;

  /// Đích khi bấm vào (chỉ là route trong danh sách cho phép), hoặc null.
  final String? payload;
}

/// Chuyển phần notification và data của một thông báo FCM thành nội dung
/// hiện cục bộ. Không có cả tiêu đề lẫn nội dung thì trả về null (không hiện).
ForegroundNotificationContent? foregroundContentFrom({
  String? title,
  String? body,
  Map<String, dynamic>? data,
}) {
  final cleanTitle = title?.trim() ?? '';
  final cleanBody = body?.trim() ?? '';
  if (cleanTitle.isEmpty && cleanBody.isEmpty) {
    return null;
  }
  return ForegroundNotificationContent(
    title: cleanTitle.isEmpty ? kDefaultNotificationTitle : cleanTitle,
    body: cleanBody,
    payload: allowedPushRoute(data),
  );
}

/// Mã thông báo theo giây (số dương 31 bit) để các thông báo liên tiếp
/// không ghi đè lên nhau.
int notificationIdFor(DateTime now) {
  return (now.millisecondsSinceEpoch ~/ 1000) & 0x7fffffff;
}
