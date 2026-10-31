import 'package:flutter_riverpod/flutter_riverpod.dart';

/// true = Firebase đã khởi tạo thành công trong main().
/// Mặc định false; main() ghi đè bằng kết quả thật. Phần thông báo đẩy chỉ
/// chạy khi giá trị này là true, còn lại app dùng bình thường.
final firebaseReadyProvider = Provider<bool>((ref) {
  return false;
});