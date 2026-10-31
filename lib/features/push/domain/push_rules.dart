/// Quyền hiện thông báo của máy, gom về 3 trạng thái.
enum PushPermission {
  /// Đã cho phép.
  granted,

  /// Đã từ chối (hoặc bị tắt trong Cài đặt).
  denied,

  /// Chưa hỏi lần nào.
  notDetermined,
}

/// Kết quả khi admin bấm "Bật thông báo".
enum PushEnableResult {
  /// Đã cấp quyền, đăng ký xong và lưu lên server.
  enabled,

  /// Admin không cho phép (hoặc hệ thống không hỏi nữa).
  denied,

  /// Đã cấp quyền nhưng đăng ký hoặc lưu lên server thất bại.
  saveFailed,

  /// Firebase không dùng được trên máy này.
  unavailable,
}

/// Có nên đăng ký âm thầm (không hộp thoại) hay không.
/// Chỉ khi Firebase chạy được, đang là admin và quyền đã được cấp.
bool shouldRegisterSilently({
  required bool firebaseReady,
  required bool isAdmin,
  required PushPermission permission,
}) {
  return firebaseReady && isAdmin && permission == PushPermission.granted;
}

/// Có nên hiện hộp thoại xin bật thông báo sau khi đăng nhập hay không.
/// Chưa cấp quyền (kể cả "từ chối" lẫn "chưa hỏi") thì hỏi, vì Android không
/// phân biệt rõ hai trạng thái này qua plugin.
bool shouldAskAtLogin({
  required bool firebaseReady,
  required PushPermission permission,
}) {
  return firebaseReady && permission != PushPermission.granted;
}