import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/features/push/domain/push_rules.dart';

/// Lớp mỏng bọc FirebaseMessaging. Mọi lỗi được ném ra cho nơi gọi xử lý.
/// Chỉ dùng khi Firebase đã khởi tạo thành công (firebaseReadyProvider).
class PushMessagingService {
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  /// Đọc quyền hiện tại, KHÔNG hiện hộp thoại hỏi.
  Future<PushPermission> currentPermission() async {
    final settings = await _messaging.getNotificationSettings();
    return _permissionFrom(settings.authorizationStatus);
  }

  /// Hiện hộp thoại xin quyền của hệ thống (Android 13 trở lên).
  Future<PushPermission> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return _permissionFrom(settings.authorizationStatus);
  }

  /// Đăng ký với FCM và trả về Firebase Installation ID (FID).
  /// Lắng nghe onRegistered TRƯỚC khi gọi register(), như tài liệu Firebase dặn.
  Future<String> registerAndGetFid({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final completer = Completer<String>();
    final subscription = _messaging.onRegistered.listen(
      (fid) {
        if (!completer.isCompleted) {
          completer.complete(fid);
        }
      },
      onError: (Object error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );
    try {
      await _messaging.register();
      return await completer.future.timeout(timeout);
    } finally {
      await subscription.cancel();
    }
  }

  /// FID mới mỗi khi FCM cấp lại (đổi FID, đăng ký lại).
  Stream<String> get fidChanges => _messaging.onRegistered;

  static PushPermission _permissionFrom(AuthorizationStatus status) {
    return switch (status) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional =>
        PushPermission.granted,
      AuthorizationStatus.denied ||
      AuthorizationStatus.deniedPermanently =>
        PushPermission.denied,
      AuthorizationStatus.notDetermined => PushPermission.notDetermined,
    };
  }
}

final pushMessagingServiceProvider = Provider<PushMessagingService>((ref) {
  return PushMessagingService();
});