const int kNicknameMinLength = 2;
const int kNicknameMaxLength = 30;

/// Bỏ khoảng trắng đầu/cuối, gộp nhiều khoảng trắng liên tiếp thành một.
String normalizeNickname(String input) {
  return input.trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Trả về câu báo lỗi tiếng Việt, hoặc null nếu hợp lệ.
String? validateNickname(String input) {
  final nickname = normalizeNickname(input);
  if (nickname.isEmpty) {
    return 'Vui lòng nhập tên của bạn.';
  }
  if (nickname.length < kNicknameMinLength) {
    return 'Tên quá ngắn, vui lòng nhập ít nhất $kNicknameMinLength ký tự.';
  }
  if (nickname.length > kNicknameMaxLength) {
    return 'Tên quá dài, tối đa $kNicknameMaxLength ký tự.';
  }
  return null;
}