import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familytree/core/errors/app_error_messages.dart';

void main() {
  test('UserFacingException: hiện đúng câu đã có sẵn', () {
    expect(
      vietnameseErrorMessage(const UserFacingException('Câu riêng.')),
      'Câu riêng.',
    );
  });

  test('StorageException 413 -> ảnh quá lớn', () {
    final error = StorageException('Payload too large', statusCode: '413');
    expect(vietnameseErrorMessage(error), kPhotoTooLargeMessage);
  });

  test('PlatformException từ chối quyền ảnh -> câu hướng dẫn cấp quyền', () {
    final error = PlatformException(code: 'photo_access_denied');
    expect(vietnameseErrorMessage(error), kPhotoPermissionMessage);
  });
}