import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familytree/core/errors/app_error_messages.dart';

void main() {
  group('lỗi đăng nhập quản trị viên', () {
    test('mã lỗi invalid_credentials -> sai mã', () {
      const error = AuthException(
        'Invalid login credentials',
        statusCode: '400',
        code: 'invalid_credentials',
      );
      expect(vietnameseErrorMessage(error), kWrongAdminCodeMessage);
    });

    test('chỉ có câu "Invalid login credentials" -> vẫn là sai mã', () {
      const error = AuthException('Invalid login credentials');
      expect(vietnameseErrorMessage(error), kWrongAdminCodeMessage);
    });

    test('429 -> thử quá nhiều lần', () {
      const error = AuthException(
        'Request rate limit reached',
        statusCode: '429',
        code: 'over_request_rate_limit',
      );
      expect(vietnameseErrorMessage(error), kTooManyAttemptsMessage);
    });

    test('AdminAccessDeniedException -> không có quyền quản trị', () {
      expect(
        vietnameseErrorMessage(const AdminAccessDeniedException()),
        kWrongAdminCodeMessage,
      );
    });

    test('AuthException lạ -> câu chung', () {
      const error = AuthException('boom', statusCode: '500');
      expect(vietnameseErrorMessage(error), kGenericErrorMessage);
    });
  });
}