import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:familytree/features/memorial/domain/memorial_reminders.dart';
import 'package:familytree/features/push/domain/foreground_notification_rules.dart';

/// Lớp mỏng bọc flutter_local_notifications. Mọi lỗi được ném ra cho nơi gọi
/// (trừ việc hẹn từng nhắc giỗ: lỗi một nhắc không làm hỏng các nhắc còn lại).
/// Dùng DUY NHẤT một thể hiện plugin cho cả thông báo đề xuất và nhắc giỗ,
/// vì hàm xử lý khi bấm thông báo chỉ đăng ký được một lần.
class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void>? _initialization;

  static const NotificationDetails _memorialDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      kMemorialChannelId,
      kMemorialChannelName,
      channelDescription: kMemorialChannelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
  );

  AndroidFlutterLocalNotificationsPlugin? get _android {
    return _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
  }

  /// Khởi tạo plugin (chỉ chạy một lần; gọi lại trả về kết quả lần đầu).
  /// Tạo hai kênh: "Đề xuất mới" (ưu tiên cao) và "Nhắc ngày giỗ" (ưu tiên
  /// thường, đỡ phiền). [onTap] nhận payload khi bấm thông báo cục bộ.
  Future<void> initialize({required void Function(String? payload) onTap}) {
    final existing = _initialization;
    if (existing != null) {
      return existing;
    }
    final future = _initializeOnce(onTap);
    _initialization = future;
    // Khởi tạo lỗi thì cho phép thử lại ở lần gọi sau.
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object _) {
          _initialization = null;
        },
      ),
    );
    return future;
  }

  Future<void> _initializeOnce(void Function(String? payload) onTap) async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        onTap(response.payload);
      },
    );

    final android = _android;
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        kRequestsChannelId,
        kRequestsChannelName,
        description: kRequestsChannelDescription,
        importance: Importance.high,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        kMemorialChannelId,
        kMemorialChannelName,
        description: kMemorialChannelDescription,
        importance: Importance.defaultImportance,
      ),
    );
  }

  /// Hoàn tất khi plugin đã khởi tạo xong. Ném lỗi nếu chưa ai gọi
  /// [initialize] hoặc khởi tạo thất bại.
  Future<void> get ready async {
    final initialization = _initialization;
    if (initialization == null) {
      throw StateError('Thông báo cục bộ chưa được khởi tạo');
    }
    await initialization;
  }

  /// Ứng dụng có được phép hiện thông báo không (Android).
  Future<bool> notificationsEnabled() async {
    await ready;
    return await _android?.areNotificationsEnabled() ?? false;
  }

  /// Hiện hộp thoại xin quyền thông báo của hệ thống (Android 13 trở lên).
  /// Trả về true nếu đã được cấp (kể cả khi đã cấp từ trước).
  Future<bool> requestNotificationPermission() async {
    await ready;
    return await _android?.requestNotificationsPermission() ?? false;
  }

  /// Payload của thông báo cục bộ đã mở app từ trạng thái tắt hẳn, hoặc null.
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) {
      return null;
    }
    return details.notificationResponse?.payload;
  }

  /// Hiện một thông báo cục bộ (dùng khi app đang mở, FCM không tự hiện).
  Future<void> show(ForegroundNotificationContent content) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        kRequestsChannelId,
        kRequestsChannelName,
        channelDescription: kRequestsChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(
      id: notificationIdFor(DateTime.now()),
      title: content.title,
      body: content.body,
      notificationDetails: details,
      payload: content.payload,
    );
  }

  /// Thông báo FCM nhận được khi app đang MỞ (foreground), đã chuẩn hóa.
  Stream<ForegroundNotificationContent> get foregroundContents {
    return FirebaseMessaging.onMessage
        .map(
          (message) => foregroundContentFrom(
            title: message.notification?.title,
            body: message.notification?.body,
            data: message.data,
          ),
        )
        .where((content) => content != null)
        .map((content) => content!);
  }

  /// Hủy MỌI nhắc giỗ đang chờ (chỉ các mã trong dải nhắc giỗ).
  Future<void> cancelMemorialReminders() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (isMemorialReminderId(request.id)) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  /// Thay toàn bộ lịch nhắc giỗ bằng [reminders]. Trả về số nhắc đặt được.
  /// Lỗi ở một nhắc được ghi log và bỏ qua, các nhắc khác vẫn được đặt.
  Future<int> replaceMemorialReminders(List<MemorialReminder> reminders) async {
    await cancelMemorialReminders();

    var scheduled = 0;
    for (final reminder in reminders) {
      try {
        await _plugin.zonedSchedule(
          id: reminder.id,
          title: reminder.title,
          body: reminder.body,
          scheduledDate: tz.TZDateTime.from(reminder.fireAtUtc, tz.UTC),
          notificationDetails: _memorialDetails,
          // Không dùng báo thức chính xác: khỏi xin quyền SCHEDULE_EXACT_ALARM,
          // chấp nhận trễ vài phút.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: reminder.payload,
        );
        scheduled++;
      } catch (error) {
        debugPrint('Không hẹn được nhắc giỗ ${reminder.id}: $error');
      }
    }
    return scheduled;
  }

  /// Hẹn một thông báo thử sau [delay] (dành cho admin kiểm tra).
  Future<void> scheduleTestMemorialReminder({
    Duration delay = const Duration(seconds: 10),
  }) async {
    await ready;
    await _plugin.zonedSchedule(
      id: kMemorialTestReminderId,
      title: kMemorialReminderTitle,
      body: 'Đây là thông báo thử. Nhắc ngày giỗ đang hoạt động.',
      scheduledDate: tz.TZDateTime.now(tz.UTC).add(delay),
      notificationDetails: _memorialDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: kMemorialReminderPayload,
    );
  }
}

final localNotificationServiceProvider = Provider<LocalNotificationService>((
  ref,
) {
  return LocalNotificationService();
});
