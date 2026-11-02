import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/memorial/domain/memorial_reminders.dart';
import 'package:familytree/features/push/domain/push_route_rules.dart';

void main() {
  group('allowedPushRoute', () {
    test('thiếu data thì null', () {
      expect(allowedPushRoute(null), isNull);
      expect(allowedPushRoute(<String, dynamic>{}), isNull);
    });

    test('nhận đúng /admin/requests', () {
      expect(
        allowedPushRoute({'route': '/admin/requests'}),
        '/admin/requests',
      );
    });

    test('nhận đúng /memorials', () {
      expect(allowedPushRoute({'route': '/memorials'}), '/memorials');
    });

    test('route khác trong ứng dụng bị bỏ', () {
      expect(allowedPushRoute({'route': '/admin/clan'}), isNull);
      expect(allowedPushRoute({'route': '/home'}), isNull);
    });

    test('route có thêm tham số bị bỏ (chỉ nhận khớp tuyệt đối)', () {
      expect(allowedPushRoute({'route': '/admin/requests?x=1'}), isNull);
      expect(allowedPushRoute({'route': '/memorials?x=1'}), isNull);
    });

    test('route sai kiểu bị bỏ', () {
      expect(allowedPushRoute({'route': 5}), isNull);
    });

    test('payload của nhắc giỗ khớp đích /memorials', () {
      expect(kMemorialReminderPayload, kMemorialsRoute);
      expect(allowedPushRoute({'route': kMemorialReminderPayload}), isNotNull);
    });
  });

  group('routeRequiresAdmin', () {
    test('route /admin/... cần admin, /memorials thì không', () {
      expect(routeRequiresAdmin(kRequestsRoute), isTrue);
      expect(routeRequiresAdmin(kMemorialsRoute), isFalse);
    });
  });

  group('decidePendingRoute', () {
    const route = '/admin/requests';
    const fresh = Duration(seconds: 2);

    test('quá hạn thì bỏ, dù đủ điều kiện', () {
      expect(
        decidePendingRoute(
          route: route,
          isAdmin: true,
          currentPath: '/home',
          age: const Duration(seconds: 31),
        ),
        PendingRouteAction.drop,
      );
    });

    test('đúng 30 giây vẫn chưa quá hạn', () {
      expect(
        decidePendingRoute(
          route: route,
          isAdmin: true,
          currentPath: '/home',
          age: const Duration(seconds: 30),
        ),
        PendingRouteAction.open,
      );
    });

    test('đã ở đúng màn thì bỏ', () {
      expect(
        decidePendingRoute(
          route: route,
          isAdmin: true,
          currentPath: route,
          age: fresh,
        ),
        PendingRouteAction.drop,
      );
    });

    test('đích dành cho admin mà chưa là admin thì đợi', () {
      expect(
        decidePendingRoute(
          route: route,
          isAdmin: false,
          currentPath: '/home',
          age: fresh,
        ),
        PendingRouteAction.wait,
      );
    });

    test('đích công khai (/memorials) thì không cần là admin', () {
      expect(
        decidePendingRoute(
          route: kMemorialsRoute,
          isAdmin: false,
          currentPath: '/home',
          age: fresh,
        ),
        PendingRouteAction.open,
      );
    });

    test('còn ở splash thì đợi (cả đích công khai)', () {
      expect(
        decidePendingRoute(
          route: route,
          isAdmin: true,
          currentPath: '/',
          age: fresh,
        ),
        PendingRouteAction.wait,
      );
      expect(
        decidePendingRoute(
          route: kMemorialsRoute,
          isAdmin: false,
          currentPath: '/',
          age: fresh,
        ),
        PendingRouteAction.wait,
      );
    });

    test('router chưa có địa chỉ thì đợi', () {
      expect(
        decidePendingRoute(
          route: route,
          isAdmin: true,
          currentPath: '',
          age: fresh,
        ),
        PendingRouteAction.wait,
      );
    });

    test('admin đang ở màn chính thì mở', () {
      expect(
        decidePendingRoute(
          route: route,
          isAdmin: true,
          currentPath: '/home',
          age: fresh,
        ),
        PendingRouteAction.open,
      );
    });

    test('admin đang ở màn khác thì cũng mở', () {
      expect(
        decidePendingRoute(
          route: route,
          isAdmin: true,
          currentPath: '/person/abc',
          age: fresh,
        ),
        PendingRouteAction.open,
      );
    });
  });
}