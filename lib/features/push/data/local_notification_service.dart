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

  /// Khởi tạo plugin và tạo hai kênh: "Đề xuất mới" (ưu tiên cao) và
  /// "Nhắc ngày giỗ" (ưu tiên thường, đỡ phiền).
  /// [onTap] nhận payload khi người dùng bấm thông báo cục bộ.
  Future<void> initialize({
    required void Function(String? payload) onTap,
  }) async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        onTap(response.payload);
      },
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
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
  Future<int> replaceMemorialReminders(
    List<MemorialReminder> reminders,
  ) async {
    await cancelMemorialReminders();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        kMemorialChannelId,
        kMemorialChannelName,
        channelDescription: kMemorialChannelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );

    var scheduled = 0;
    for (final reminder in reminders) {
      try {
        await _plugin.zonedSchedule(
          id: reminder.id,
          title: reminder.title,
          body: reminder.body,
          scheduledDate: tz.TZDateTime.from(reminder.fireAtUtc, tz.UTC),
          notificationDetails: details,
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
}

final localNotificationServiceProvider =
    Provider<LocalNotificationService>((ref) {
  return LocalNotificationService();
});