import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Câu chung cho mọi mã lỗi lạ.
const String kGenericErrorMessage = 'Có lỗi xảy ra, vui lòng thử lại.';

/// Câu cho lỗi mạng.
const String kNetworkErrorMessage =
    'Không kết nối được mạng. Vui lòng kiểm tra mạng rồi thử lại.';

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

  for (final match in _codeToken.allMatches(text)) {
    final message = kErrorMessagesVi[match.group(0)];
    if (message != null) {
      return message;
    }
  }

  // 42501 = Postgres từ chối quyền (RLS).
  if (error is PostgrestException && error.code == '42501') {
    return kErrorMessagesVi['FORBIDDEN']!;
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