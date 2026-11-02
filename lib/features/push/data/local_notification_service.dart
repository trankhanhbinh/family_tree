import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/features/push/domain/foreground_notification_rules.dart';

/// Lớp mỏng bọc flutter_local_notifications. Mọi lỗi được ném ra cho nơi gọi.
/// Chỉ dùng khi Firebase đã khởi tạo thành công (firebaseReadyProvider).
class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Khởi tạo plugin và tạo kênh "Đề xuất mới" (độ ưu tiên cao).
  /// [onTap] nhận payload khi admin bấm thông báo cục bộ.
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
}

final localNotificationServiceProvider =
    Provider<LocalNotificationService>((ref) {
  return LocalNotificationService();
});