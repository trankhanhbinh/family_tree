/// Đích duy nhất mà thông báo "Có đề xuất mới" được phép mở.
const String kRequestsRoute = '/admin/requests';

/// Đích đang chờ quá lâu thì bỏ (không chuyển màn bất ngờ về sau).
const Duration kPendingRouteMaxAge = Duration(seconds: 30);

/// Đường dẫn của màn khởi động (splash).
const String kSplashPath = '/';

/// Đọc đích từ phần data của thông báo. Chỉ nhận đúng các đích trong danh
/// sách cho phép; còn lại (thiếu, sai kiểu, route lạ) trả về null.
String? allowedPushRoute(Map<String, dynamic>? data) {
  final route = data?['route'];
  if (route is String && route == kRequestsRoute) {
    return route;
  }
  return null;
}

/// Việc cần làm với đích đang chờ.
enum PendingRouteAction {
  /// Chưa đủ điều kiện, giữ lại và đợi.
  wait,

  /// Đủ điều kiện, chuyển màn ngay.
  open,

  /// Bỏ đích này (quá hạn hoặc đã ở đúng màn).
  drop,
}

/// Quyết định có chuyển sang [route] chưa.
/// Thứ tự xét: quá hạn thì bỏ, đang ở đúng màn thì bỏ, chưa là admin hoặc
/// còn ở splash (hoặc router chưa có địa chỉ) thì đợi, còn lại thì mở.
PendingRouteAction decidePendingRoute({
  required String route,
  required bool isAdmin,
  required String currentPath,
  required Duration age,
}) {
  if (age > kPendingRouteMaxAge) {
    return PendingRouteAction.drop;
  }
  if (currentPath == route) {
    return PendingRouteAction.drop;
  }
  if (!isAdmin || currentPath.isEmpty || currentPath == kSplashPath) {
    return PendingRouteAction.wait;
  }
  return PendingRouteAction.open;
}