import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/push/domain/foreground_notification_rules.dart';

void main() {
  group('foregroundContentFrom', () {
    test('không có tiêu đề lẫn nội dung thì null', () {
      expect(foregroundContentFrom(), isNull);
      expect(foregroundContentFrom(title: '  ', body: ''), isNull);
    });

    test('đủ tiêu đề, nội dung và route cho phép thì có payload', () {
      final content = foregroundContentFrom(
        title: 'Có đề xuất mới',
        body: 'An gửi 3 thay đổi, bấm để xem',
        data: {'route': '/admin/requests'},
      );
      expect(content, isNotNull);
      expect(content!.title, 'Có đề xuất mới');
      expect(content.body, 'An gửi 3 thay đổi, bấm để xem');
      expect(content.payload, '/admin/requests');
    });

    test('thiếu tiêu đề thì dùng tiêu đề mặc định', () {
      final content = foregroundContentFrom(body: 'Nội dung');
      expect(content!.title, kDefaultNotificationTitle);
    });

    test('thiếu nội dung thì nội dung rỗng', () {
      final content = foregroundContentFrom(title: 'Tiêu đề');
      expect(content!.body, '');
    });

    test('route lạ thì payload null', () {
      final content = foregroundContentFrom(
        title: 'Tiêu đề',
        data: {'route': '/admin/clan'},
      );
      expect(content!.payload, isNull);
    });

    test('cắt khoảng trắng đầu cuối', () {
      final content = foregroundContentFrom(
        title: '  Tiêu đề  ',
        body: '  Nội dung  ',
      );
      expect(content!.title, 'Tiêu đề');
      expect(content.body, 'Nội dung');
    });
  });

  group('notificationIdFor', () {
    test('luôn là số dương trong giới hạn 31 bit', () {
      final id = notificationIdFor(DateTime.utc(2026, 11, 2, 12, 30, 45));
      expect(id, greaterThan(0));
      expect(id, lessThanOrEqualTo(0x7fffffff));
    });

    test('cùng một giây cho cùng mã, khác giây cho mã khác', () {
      final a = DateTime.utc(2026, 11, 2, 12, 30, 45, 100);
      final b = DateTime.utc(2026, 11, 2, 12, 30, 45, 900);
      final c = DateTime.utc(2026, 11, 2, 12, 30, 46);
      expect(notificationIdFor(a), notificationIdFor(b));
      expect(notificationIdFor(a), isNot(notificationIdFor(c)));
    });
  });

  test('mã kênh khớp với AndroidManifest.xml', () {
    expect(kRequestsChannelId, 'new_requests');
  });
}
