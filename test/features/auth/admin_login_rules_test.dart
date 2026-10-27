import 'package:flutter_test/flutter_test.dart';
import 'package:familytree/features/auth/domain/admin_login_rules.dart';

void main() {
  group('mã quản trị', () {
    test('normalizeAdminCode cắt khoảng trắng hai đầu', () {
      expect(normalizeAdminCode('  abc 123 \n'), 'abc 123');
    });

    test('validateAdminCode: rỗng -> báo lỗi', () {
      expect(validateAdminCode(''), kAdminCodeEmptyMessage);
    });

    test('validateAdminCode: toàn khoảng trắng -> báo lỗi', () {
      expect(validateAdminCode('   '), kAdminCodeEmptyMessage);
    });

    test('validateAdminCode: có mã -> null', () {
      expect(validateAdminCode(' ma-bi-mat '), isNull);
    });
  });

  group('shouldVerifyAdminOnStart', () {
    test('không có phiên -> false', () {
      expect(
        shouldVerifyAdminOnStart(hasSession: false, isAnonymous: true),
        isFalse,
      );
    });

    test('phiên ẩn danh -> false', () {
      expect(
        shouldVerifyAdminOnStart(hasSession: true, isAnonymous: true),
        isFalse,
      );
    });

    test('phiên thường (không ẩn danh) -> true', () {
      expect(
        shouldVerifyAdminOnStart(hasSession: true, isAnonymous: false),
        isTrue,
      );
    });
  });
}