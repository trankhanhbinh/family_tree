import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:familytree/features/memorial/data/memorial_reminder_controller.dart';
import 'package:familytree/features/memorial/data/memorial_reminder_store.dart';
import 'package:familytree/features/memorial/domain/memorial_reminders.dart';
import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/push/data/local_notification_service.dart';

/// Dịch vụ giả: ghi lại các lần gọi, không chạm vào plugin thật.
class _FakeService implements LocalNotificationService {
  bool notificationsOn = true;
  bool grantOnRequest = true;
  bool readyFails = false;
  int permissionRequests = 0;
  int cancelCount = 0;
  int testCount = 0;
  final List<List<MemorialReminder>> replaced = [];

  @override
  Future<void> get ready async {
    if (readyFails) {
      throw StateError('chưa khởi tạo');
    }
  }

  @override
  Future<bool> notificationsEnabled() async => notificationsOn;

  @override
  Future<bool> requestNotificationPermission() async {
    permissionRequests++;
    if (grantOnRequest) {
      notificationsOn = true;
    }
    return grantOnRequest;
  }

  @override
  Future<int> replaceMemorialReminders(
    List<MemorialReminder> reminders,
  ) async {
    replaced.add(reminders);
    return reminders.length;
  }

  @override
  Future<void> cancelMemorialReminders() async {
    cancelCount++;
  }

  @override
  Future<void> scheduleTestMemorialReminder({
    Duration delay = const Duration(seconds: 10),
  }) async {
    testCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Person _p(String id, String name, {required int day, required int month}) {
  return Person(
    id: id,
    fullName: name,
    gender: Gender.male,
    isAlive: false,
    memorialLunarDay: day,
    memorialLunarMonth: month,
    memorialIsLeap: false,
    deletedAt: null,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 03:00 UTC ngày 01/08/2024 = 10:00 giờ Việt Nam. Giỗ 15/7 âm = 18/08/2024.
  final people = [_p('a', 'Một', day: 15, month: 7)];

  late _FakeService service;
  late MemorialReminderStore store;
  late MemorialReminderController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    service = _FakeService();
    store = MemorialReminderStore();
    controller = MemorialReminderController(
      service: service,
      store: store,
      now: () => DateTime.utc(2024, 8, 1, 3, 0),
    );
  });

  group('enable', () {
    test('không được cấp quyền thì không lưu cờ và không hẹn', () async {
      service
        ..notificationsOn = false
        ..grantOnRequest = false;
      final outcome = await controller.enable(people);
      expect(outcome.result, MemorialReminderEnableResult.denied);
      expect(await store.isEnabled(), isFalse);
      expect(service.replaced, isEmpty);
    });

    test('được cấp quyền thì lưu cờ và hẹn lịch', () async {
      final outcome = await controller.enable(people);
      expect(outcome.result, MemorialReminderEnableResult.enabled);
      expect(outcome.scheduledCount, 1);
      expect(await store.isEnabled(), isTrue);
      expect(service.replaced.length, 1);
      expect(
        service.replaced.first.first.fireAtVietnam,
        DateTime(2024, 8, 15, 20, 30),
      );
    });

    test('chưa có ngày giỗ cần nhắc thì vẫn bật, hẹn 0 lần', () async {
      final outcome = await controller.enable(const <Person>[]);
      expect(outcome.result, MemorialReminderEnableResult.enabled);
      expect(outcome.scheduledCount, 0);
      expect(await store.isEnabled(), isTrue);
    });

    test('dịch vụ chưa khởi tạo thì báo lỗi, không lưu cờ', () async {
      service.readyFails = true;
      final outcome = await controller.enable(people);
      expect(outcome.result, MemorialReminderEnableResult.failed);
      expect(await store.isEnabled(), isFalse);
    });
  });

  group('disable', () {
    test('ghi cờ tắt và hủy các nhắc', () async {
      await store.setEnabled(true);
      await controller.disable();
      expect(await store.isEnabled(), isFalse);
      expect(service.cancelCount, 1);
    });
  });

  group('syncIfEnabled', () {
    test('chưa bật thì không hẹn gì', () async {
      await controller.syncIfEnabled(people);
      expect(service.replaced, isEmpty);
    });

    test('đã bật và còn quyền thì hẹn lại', () async {
      await store.setEnabled(true);
      await controller.syncIfEnabled(people);
      expect(service.replaced.length, 1);
      expect(service.replaced.first.length, 1);
    });

    test('đã bật nhưng quyền bị tắt thì không hẹn, vẫn giữ cờ', () async {
      await store.setEnabled(true);
      service.notificationsOn = false;
      await controller.syncIfEnabled(people);
      expect(service.replaced, isEmpty);
      expect(await store.isEnabled(), isTrue);
    });

    test('dịch vụ lỗi thì không ném lỗi ra ngoài', () async {
      await store.setEnabled(true);
      service.readyFails = true;
      await controller.syncIfEnabled(people);
      expect(service.replaced, isEmpty);
    });

    test('hai lần gọi liên tiếp đều được thực hiện lần lượt', () async {
      await store.setEnabled(true);
      await Future.wait([
        controller.syncIfEnabled(people),
        controller.syncIfEnabled(people),
      ]);
      expect(service.replaced.length, 2);
    });
  });

  group('sendTest', () {
    test('đã có quyền thì hẹn thông báo thử', () async {
      expect(await controller.sendTest(), isTrue);
      expect(service.testCount, 1);
      expect(service.permissionRequests, 0);
    });

    test('chưa có quyền thì xin, được cấp thì hẹn', () async {
      service.notificationsOn = false;
      expect(await controller.sendTest(), isTrue);
      expect(service.permissionRequests, 1);
      expect(service.testCount, 1);
    });

    test('không được cấp quyền thì trả về false', () async {
      service
        ..notificationsOn = false
        ..grantOnRequest = false;
      expect(await controller.sendTest(), isFalse);
      expect(service.testCount, 0);
    });
  });

  test('mã thông báo thử nằm trong dải nhắc giỗ (tự bị dọn khi lập lịch)', () {
    expect(isMemorialReminderId(kMemorialTestReminderId), isTrue);
  });
}