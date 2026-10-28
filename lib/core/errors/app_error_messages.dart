import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Câu chung cho mọi mã lỗi lạ.
const String kGenericErrorMessage = 'Có lỗi xảy ra, vui lòng thử lại.';

/// Câu cho lỗi mạng.
const String kNetworkErrorMessage =
    'Không kết nối được mạng. Vui lòng kiểm tra mạng rồi thử lại.';

/// Sai mã quản trị, hoặc đăng nhập được nhưng không phải admin.
const String kWrongAdminCodeMessage =
    'Mã không đúng hoặc không có quyền quản trị.';

/// Đăng nhập sai quá nhiều lần (server giới hạn tốc độ).
const String kTooManyAttemptsMessage =
    'Bạn đã thử quá nhiều lần. Vui lòng đợi vài phút rồi thử lại.';

/// Lỗi khóa ngoại Postgres (23503): dữ liệu liên quan không còn.
const String kRelatedDataMissingMessage =
    'Dữ liệu liên quan không còn tồn tại. '
    'Hãy bấm "Làm mới" ở màn hình cây rồi thử lại.';

/// Lỗi ảnh.
const String kPhotoTooLargeMessage =
    'Ảnh quá lớn (tối đa 3 MB). Hãy chọn ảnh nhỏ hơn.';
const String kPhotoTypeMessage = 'Chỉ nhận ảnh JPEG, PNG hoặc WebP.';
const String kPhotoPermissionMessage =
    'Ứng dụng chưa được cấp quyền truy cập ảnh hoặc camera. '
    'Hãy cấp quyền trong phần Cài đặt của điện thoại rồi thử lại.';

/// Lỗi do chính app tạo ra, đã có sẵn câu tiếng Việt để hiện cho người dùng.
class UserFacingException implements Exception {
  const UserFacingException(this.message);

  final String message;

  @override
  String toString() => 'UserFacingException';
}

/// Ném khi đăng nhập thành công nhưng is_admin() trả về false.
class AdminAccessDeniedException implements Exception {
  const AdminAccessDeniedException();

  @override
  String toString() => 'AdminAccessDeniedException';
}

/// 13 mã lỗi do database ném ra (RAISE EXCEPTION) -> câu tiếng Việt.
const Map<String, String> kErrorMessagesVi = {
  'REQUEST_LIMIT_REACHED':
      'Bạn đang có quá nhiều đề xuất chờ duyệt (tối đa 10). '
          'Vui lòng đợi quản trị viên duyệt bớt rồi gửi tiếp.',
  'CYCLE_DETECTED':
      'Thay đổi này làm quan hệ bị vòng lặp '
          '(một người trở thành tổ tiên của chính mình). '
          'Vui lòng kiểm tra lại.',
  'HAS_DESCENDANTS':
      'Không thể xóa người này vì vẫn còn con cháu. '
          'Hãy xử lý con cháu trước.',
  'BRANCH_NOT_EMPTY':
      'Không thể xóa chi/nhánh này vì vẫn còn người thuộc chi/nhánh.',
  'ALREADY_REVIEWED': 'Đề xuất này đã được xử lý rồi.',
  'REQUEST_NOT_FOUND': 'Không tìm thấy đề xuất này. Có thể đã bị xóa.',
  'ENTITY_NOT_FOUND':
      'Không tìm thấy mục cần thay đổi. Có thể đã bị xóa. '
          'Hãy bấm "Làm mới" ở màn hình cây.',
  'FORBIDDEN': 'Bạn không có quyền thực hiện thao tác này.',
  'INVALID_PAYLOAD_KEY':
      'Nội dung đề xuất có một mục không được phép. '
          'Vui lòng báo người làm app.',
  'INVALID_PAYLOAD':
      'Nội dung đề xuất không hợp lệ. Vui lòng kiểm tra lại các ô đã nhập.',
  'EMPTY_PAYLOAD': 'Đề xuất chưa có nội dung nào thay đổi.',
  'INVALID_ACTION':
      'Loại thao tác không hợp lệ. Vui lòng báo người làm app.',
  'PHOTO_FILE_MISSING': 'Không tìm thấy tệp ảnh. Vui lòng tải ảnh lên lại.',
};

// Một "từ mã lỗi" = chữ HOA, số, gạch dưới (INVALID_PAYLOAD_KEY là MỘT từ,
// nên không bị nhầm với INVALID_PAYLOAD).
final RegExp _codeToken = RegExp(r'[A-Z][A-Z0-9_]+');

const List<String> _networkHints = [
  'SocketException',
  'ClientException',
  'TimeoutException',
  'Failed host lookup',
  'Connection refused',
  'Connection reset',
  'Connection closed',
  'Network is unreachable',
];

/// MỘT hàm duy nhất đổi lỗi bất kỳ thành câu tiếng Việt dễ hiểu.
String vietnameseErrorMessage(Object error) {
  final text = _errorText(error);

  if (error is AdminAccessDeniedException) {
    return kWrongAdminCodeMessage;
  }
  if (error is UserFacingException) {
    return error.message;
  }

  for (final match in _codeToken.allMatches(text)) {
    final message = kErrorMessagesVi[match.group(0)];
    if (message != null) {
      return message;
    }
  }

  if (error is AuthException) {
    final authMessage = _authErrorMessage(error);
    if (authMessage != null) {
      return authMessage;
    }
  }

  if (error is StorageException) {
    final storageMessage = _storageErrorMessage(error);
    if (storageMessage != null) {
      return storageMessage;
    }
  }

  if (error is PlatformException) {
    final code = error.code;
    if (code.contains('access_denied') || code.contains('permission')) {
      return kPhotoPermissionMessage;
    }
  }

  // 42501 = Postgres từ chối quyền (RLS).
  if (error is PostgrestException && error.code == '42501') {
    return kErrorMessagesVi['FORBIDDEN']!;
  }

  // 23503 = vi phạm khóa ngoại (vd quan hệ trỏ tới người không còn).
  if (error is PostgrestException && error.code == '23503') {
    return kRelatedDataMissingMessage;
  }

  if (_isNetworkError(error, text)) {
    return kNetworkErrorMessage;
  }

  if (kDebugMode) {
    debugPrint('Lỗi chưa ánh xạ: $error');
  }
  return kGenericErrorMessage;
}

String _errorText(Object error) {
  if (error is PostgrestException) {
    return '${error.message} ${error.details ?? ''} ${error.hint ?? ''}';
  }
  return error.toString();
}

bool _isNetworkError(Object error, String text) {
  if (error is SocketException || error is TimeoutException) {
    return true;
  }
  return _networkHints.any(text.contains);
}

/// Lỗi đăng nhập của Supabase Auth. Trả null nếu không nhận ra
/// (lỗi mạng rơi xuống phần dò từ khóa mạng phía dưới).
String? _authErrorMessage(AuthException error) {
  final status = error.statusCode ?? '';
  final code = error.code ?? '';
  final message = error.message.toLowerCase();

  if (status == '429' ||
      code.contains('rate_limit') ||
      message.contains('rate limit')) {
    return kTooManyAttemptsMessage;
  }
  if (code == 'invalid_credentials' ||
      message.contains('invalid login credentials')) {
    return kWrongAdminCodeMessage;
  }
  return null;
}

/// Lỗi của Supabase Storage. Trả null nếu không nhận ra.
String? _storageErrorMessage(StorageException error) {
  final status = error.statusCode ?? '';
  final message = error.message.toLowerCase();

  if (status == '413' ||
      message.contains('too large') ||
      message.contains('exceeded the maximum')) {
    return kPhotoTooLargeMessage;
  }
  if (status == '415' ||
      message.contains('mime type') ||
      message.contains('not supported')) {
    return kPhotoTypeMessage;
  }
  if (status == '401' ||
      status == '403' ||
      message.contains('row-level security') ||
      message.contains('unauthorized')) {
    return kErrorMessagesVi['FORBIDDEN'];
  }
  return null;
}