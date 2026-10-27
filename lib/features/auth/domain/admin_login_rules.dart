/// Câu báo khi chưa nhập mã quản trị.
const String kAdminCodeEmptyMessage = 'Vui lòng nhập mã quản trị.';

/// Cắt khoảng trắng hai đầu (bàn phím điện thoại hay tự thêm dấu cách).
/// Mã quản trị vì vậy KHÔNG được bắt đầu/kết thúc bằng dấu cách.
String normalizeAdminCode(String raw) => raw.trim();

/// Trả về câu lỗi, hoặc null nếu hợp lệ.
String? validateAdminCode(String raw) {
  return normalizeAdminCode(raw).isEmpty ? kAdminCodeEmptyMessage : null;
}

/// Khi mở app: chỉ cần hỏi server "có phải admin không" nếu đang giữ
/// một phiên KHÔNG ẩn danh.
bool shouldVerifyAdminOnStart({
  required bool hasSession,
  required bool isAnonymous,
}) {
  return hasSession && !isAnonymous;
}