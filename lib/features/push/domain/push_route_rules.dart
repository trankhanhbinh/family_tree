/// Đích của thông báo "Có đề xuất mới": màn duyệt đề xuất (chỉ admin).
const String kRequestsRoute = '/admin/requests';

/// Đích của nhắc ngày giỗ: màn Ngày giỗ (ai cũng xem được).
const String kMemorialsRoute = '/memorials';

/// Đích chờ quá lâu thì bỏ (không chuyển màn bất ngờ về sau).
const Duration kPendingRouteMaxAge = Duration(seconds: 30);

/// Đường dẫn của màn khởi động (splash).
const String kSplashPath = '/';

/// Danh sách các đích được phép mở từ thông báo.
const Set<String> kAllowedPushRoutes = {kRequestsRoute, kMemorialsRoute};

/// Đọc đích từ phần data của thông báo. Chỉ nhận đúng các đích trong danh
/// sách cho phép; còn lại (thiếu, sai kiểu, route lạ) trả về null.
String? allowedPushRoute(Map<String, dynamic>? data) {
  final route = data?['route'];
  if (route is String && kAllowedPushRoutes.contains(route)) {
    return route;
  }
  return null;
}

/// Đích này có chỉ dành cho admin không (các route /admin/...).
bool routeRequiresAdmin(String route) {
  return route.startsWith('/admin/');
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
/// Thứ tự xét: quá hạn thì bỏ, đang ở đúng màn thì bỏ, còn ở splash (hoặc
/// router chưa có địa chỉ) thì đợi, đích dành cho admin mà chưa là admin thì
/// đợi, còn lại thì mở.
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
  if (currentPath.isEmpty || currentPath == kSplashPath) {
    return PendingRouteAction.wait;
  }
  if (routeRequiresAdmin(route) && !isAdmin) {
    return PendingRouteAction.wait;
  }
  return PendingRouteAction.open;
}