import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/features/memorial/data/memorial_reminder_store.dart';
import 'package:familytree/features/memorial/domain/memorial_reminders.dart';
import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/push/data/local_notification_service.dart';

/// Kết quả khi người dùng bật nhắc ngày giỗ.
enum MemorialReminderEnableResult {
  /// Đã được cấp quyền, đã lưu cờ và hẹn lịch.
  enabled,

  /// Người dùng không cho phép thông báo.
  denied,

  /// Có lỗi khác (khởi tạo hoặc hẹn lịch).
  failed,
}

class MemorialReminderEnableOutcome {
  const MemorialReminderEnableOutcome({
    required this.result,
    required this.scheduledCount,
  });

  final MemorialReminderEnableResult result;

  /// Số lần nhắc đã hẹn (0 nếu chưa có ngày giỗ nào cần nhắc).
  final int scheduledCount;
}

/// Điều phối nhắc ngày giỗ: bật/tắt, xin quyền, hẹn lịch và lập lại lịch.
/// Các hàm "âm thầm" (syncIfEnabled, sendTest) không bao giờ ném lỗi.
class MemorialReminderController {
  MemorialReminderController({
    required this._service,
    required this._store,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final LocalNotificationService _service;
  final MemorialReminderStore _store;
  final DateTime Function() _now;

  // Các lần hẹn lịch chạy lần lượt, không chồng lên nhau.
  Future<void> _queue = Future<void>.value();

  Future<T> _enqueue<T>(Future<T> Function() task) {
    final result = _queue.then((_) => task());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<int> _schedule(List<Person> people) {
    final plan = planMemorialReminders(
      people: people,
      nowVietnam: vietnamWallClock(_now()),
    );
    return _service.replaceMemorialReminders(plan);
  }

  /// Người dùng đã bật nhắc ngày giỗ trên máy này chưa.
  Future<bool> isEnabled() => _store.isEnabled();

  /// Ứng dụng có đang được phép hiện thông báo không. Lỗi thì coi là không.
  Future<bool> notificationsAllowed() async {
    try {
      return await _service.notificationsEnabled();
    } catch (error) {
      debugPrint('Không đọc được quyền thông báo (bỏ qua): $error');
      return false;
    }
  }

  /// Người dùng vừa bật công tắc: xin quyền, lưu cờ rồi hẹn lịch.
  Future<MemorialReminderEnableOutcome> enable(List<Person> people) async {
    try {
      await _service.ready;
      final granted = await _service.requestNotificationPermission();
      if (!granted) {
        return const MemorialReminderEnableOutcome(
          result: MemorialReminderEnableResult.denied,
          scheduledCount: 0,
        );
      }
      await _store.setEnabled(true);
      final count = await _enqueue(() => _schedule(people));
      return MemorialReminderEnableOutcome(
        result: MemorialReminderEnableResult.enabled,
        scheduledCount: count,
      );
    } catch (error) {
      debugPrint('Bật nhắc ngày giỗ thất bại: $error');
      return const MemorialReminderEnableOutcome(
        result: MemorialReminderEnableResult.failed,
        scheduledCount: 0,
      );
    }
  }

  /// Người dùng tắt công tắc: ghi cờ tắt rồi hủy mọi nhắc đã hẹn.
  Future<void> disable() async {
    await _store.setEnabled(false);
    try {
      await _service.ready;
      await _enqueue(_service.cancelMemorialReminders);
    } catch (error) {
      debugPrint('Hủy nhắc ngày giỗ thất bại (bỏ qua): $error');
    }
  }

  /// Lập lại lịch nếu người dùng đã bật và quyền thông báo còn được cấp.
  /// Gọi khi mở app, khi quay lại app và khi dữ liệu cây đổi.
  Future<void> syncIfEnabled(List<Person> people) async {
    try {
      if (!await _store.isEnabled()) {
        return;
      }
      await _service.ready;
      if (!await _service.notificationsEnabled()) {
        return;
      }
      await _enqueue(() => _schedule(people));
    } catch (error) {
      debugPrint('Lập lại lịch nhắc ngày giỗ thất bại (bỏ qua): $error');
    }
  }

  /// Hẹn thông báo thử sau 10 giây. Trả về false nếu chưa có quyền hoặc lỗi.
  Future<bool> sendTest() async {
    try {
      await _service.ready;
      var allowed = await _service.notificationsEnabled();
      if (!allowed) {
        allowed = await _service.requestNotificationPermission();
      }
      if (!allowed) {
        return false;
      }
      await _service.scheduleTestMemorialReminder();
      return true;
    } catch (error) {
      debugPrint('Hẹn thông báo thử thất bại: $error');
      return false;
    }
  }
}

final memorialReminderControllerProvider = Provider<MemorialReminderController>(
  (ref) {
    return MemorialReminderController(
      service: ref.watch(localNotificationServiceProvider),
      store: ref.watch(memorialReminderStoreProvider),
    );
  },
);
