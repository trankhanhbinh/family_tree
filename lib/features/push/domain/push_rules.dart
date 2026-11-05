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

/// Trạng thái thông báo của máy này, hiển thị ở màn "Thông báo đề xuất mới".
enum PushStatus {
  /// Firebase không khởi tạo được: máy này không dùng được thông báo.
  unavailable,

  /// Admin đã chủ động tắt thông báo trên máy này.
  turnedOff,

  /// Chưa cấp quyền hiện thông báo.
  notEnabled,

  /// Đã cấp quyền nhưng máy chưa có FID đã lưu (đăng ký hoặc lưu bị lỗi).
  notSaved,

  /// Đang bật: đã cấp quyền và đã lưu FID.
  enabled,
}

/// Suy ra trạng thái từ bản ghi trên máy (không hỏi server).
/// Thứ tự xét: không dùng được, rồi đã tắt, rồi chưa bật, rồi chưa lưu được,
/// cuối cùng là đang bật.
PushStatus pushStatusFrom({
  required bool firebaseReady,
  required PushPermission permission,
  required bool hasSavedFid,
  required bool optedOut,
}) {
  if (!firebaseReady) {
    return PushStatus.unavailable;
  }
  if (optedOut) {
    return PushStatus.turnedOff;
  }
  if (permission != PushPermission.granted) {
    return PushStatus.notEnabled;
  }
  if (!hasSavedFid) {
    return PushStatus.notSaved;
  }
  return PushStatus.enabled;
}
