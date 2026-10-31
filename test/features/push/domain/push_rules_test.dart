import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/push/domain/push_rules.dart';

void main() {
  group('shouldRegisterSilently', () {
    test('đủ ba điều kiện thì đăng ký', () {
      expect(
        shouldRegisterSilently(
          firebaseReady: true,
          isAdmin: true,
          permission: PushPermission.granted,
        ),
        isTrue,
      );
    });

    test('Firebase chưa sẵn sàng thì không đăng ký', () {
      expect(
        shouldRegisterSilently(
          firebaseReady: false,
          isAdmin: true,
          permission: PushPermission.granted,
        ),
        isFalse,
      );
    });

    test('không phải admin thì không đăng ký', () {
      expect(
        shouldRegisterSilently(
          firebaseReady: true,
          isAdmin: false,
          permission: PushPermission.granted,
        ),
        isFalse,
      );
    });

    test('quyền bị từ chối thì không đăng ký', () {
      expect(
        shouldRegisterSilently(
          firebaseReady: true,
          isAdmin: true,
          permission: PushPermission.denied,
        ),
        isFalse,
      );
    });

    test('chưa hỏi quyền thì không đăng ký âm thầm', () {
      expect(
        shouldRegisterSilently(
          firebaseReady: true,
          isAdmin: true,
          permission: PushPermission.notDetermined,
        ),
        isFalse,
      );
    });
  });

  group('shouldAskAtLogin', () {
    test('đã cấp quyền thì không hỏi', () {
      expect(
        shouldAskAtLogin(
          firebaseReady: true,
          permission: PushPermission.granted,
        ),
        isFalse,
      );
    });

    test('đã từ chối thì hỏi lại', () {
      expect(
        shouldAskAtLogin(
          firebaseReady: true,
          permission: PushPermission.denied,
        ),
        isTrue,
      );
    });

    test('chưa hỏi lần nào thì hỏi', () {
      expect(
        shouldAskAtLogin(
          firebaseReady: true,
          permission: PushPermission.notDetermined,
        ),
        isTrue,
      );
    });

    test('Firebase chưa sẵn sàng thì không hỏi', () {
      expect(
        shouldAskAtLogin(
          firebaseReady: false,
          permission: PushPermission.notDetermined,
        ),
        isFalse,
      );
    });
  });
}