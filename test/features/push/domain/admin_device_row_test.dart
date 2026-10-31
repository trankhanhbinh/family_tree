import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/push/domain/admin_device_row.dart';

void main() {
  final now = DateTime.utc(2026, 11, 1, 10, 30, 15);

  group('buildAdminDeviceRow', () {
    test('tạo đủ 3 khóa, mặc định android, không có user_id', () {
      final row = buildAdminDeviceRow(fid: 'abc123', now: now);

      expect(row.keys.toSet(), {'fcm_token', 'platform', 'last_seen_at'});
      expect(row['fcm_token'], 'abc123');
      expect(row['platform'], 'android');
      expect(row.containsKey('user_id'), isFalse);
    });

    test('last_seen_at là giờ UTC dạng ISO 8601', () {
      final row = buildAdminDeviceRow(fid: 'abc123', now: now);

      expect(row['last_seen_at'], '2026-11-01T10:30:15.000Z');
    });

    test('giờ địa phương được đổi sang UTC', () {
      final local = DateTime.utc(2026, 11, 1, 3, 0, 0).toLocal();
      final row = buildAdminDeviceRow(fid: 'abc123', now: local);

      expect(row['last_seen_at'], '2026-11-01T03:00:00.000Z');
    });

    test('cắt khoảng trắng hai đầu của FID', () {
      final row = buildAdminDeviceRow(fid: '  abc123 \n', now: now);

      expect(row['fcm_token'], 'abc123');
    });

    test('FID rỗng hoặc toàn khoảng trắng thì ném ArgumentError', () {
      expect(
        () => buildAdminDeviceRow(fid: '', now: now),
        throwsArgumentError,
      );
      expect(
        () => buildAdminDeviceRow(fid: '   ', now: now),
        throwsArgumentError,
      );
    });

    test('chỉ nhận platform android hoặc ios', () {
      expect(
        buildAdminDeviceRow(fid: 'abc123', now: now, platform: 'ios')['platform'],
        'ios',
      );
      expect(
        () => buildAdminDeviceRow(fid: 'abc123', now: now, platform: 'web'),
        throwsArgumentError,
      );
    });
  });
}