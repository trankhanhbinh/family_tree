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

  group('pushStatusFrom', () {
    test('Firebase không dùng được thì unavailable, bất kể gì khác', () {
      expect(
        pushStatusFrom(
          firebaseReady: false,
          permission: PushPermission.granted,
          hasSavedFid: true,
          optedOut: true,
        ),
        PushStatus.unavailable,
      );
    });

    test('đã tắt thì turnedOff dù quyền và FID còn nguyên', () {
      expect(
        pushStatusFrom(
          firebaseReady: true,
          permission: PushPermission.granted,
          hasSavedFid: true,
          optedOut: true,
        ),
        PushStatus.turnedOff,
      );
    });

    test('chưa cấp quyền thì notEnabled (cả từ chối lẫn chưa hỏi)', () {
      for (final permission in [
        PushPermission.denied,
        PushPermission.notDetermined,
      ]) {
        expect(
          pushStatusFrom(
            firebaseReady: true,
            permission: permission,
            hasSavedFid: true,
            optedOut: false,
          ),
          PushStatus.notEnabled,
        );
      }
    });

    test('đã cấp quyền nhưng chưa có FID thì notSaved', () {
      expect(
        pushStatusFrom(
          firebaseReady: true,
          permission: PushPermission.granted,
          hasSavedFid: false,
          optedOut: false,
        ),
        PushStatus.notSaved,
      );
    });

    test('đã cấp quyền và có FID thì enabled', () {
      expect(
        pushStatusFrom(
          firebaseReady: true,
          permission: PushPermission.granted,
          hasSavedFid: true,
          optedOut: false,
        ),
        PushStatus.enabled,
      );
    });
  });
}