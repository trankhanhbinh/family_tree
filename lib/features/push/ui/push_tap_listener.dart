import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:familytree/core/router/app_router.dart';
import 'package:familytree/features/auth/data/admin_provider.dart';
import 'package:familytree/features/push/data/firebase_ready_provider.dart';
import 'package:familytree/features/push/data/local_notification_service.dart';
import 'package:familytree/features/push/data/push_messaging_service.dart';
import 'package:familytree/features/push/domain/foreground_notification_rules.dart';
import 'package:familytree/features/push/domain/push_route_rules.dart';
import 'package:familytree/features/review/data/review_repository.dart';

/// Bọc ngoài AdminShell (qua builder của MaterialApp.router).
/// - Bấm thông báo (nền, đã tắt, hoặc thông báo cục bộ như nhắc ngày giỗ):
///   nhớ đích, đợi qua splash (và đợi xác nhận quyền admin nếu đích dành cho
///   admin), rồi mở màn tương ứng.
/// - App đang mở: FCM không tự hiện thông báo nên hiện bằng thông báo cục bộ
///   và làm mới danh sách "Chờ duyệt".
class PushTapListener extends ConsumerStatefulWidget {
  const PushTapListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PushTapListener> createState() => _PushTapListenerState();
}

class _PushTapListenerState extends ConsumerState<PushTapListener> {
  late final GoRouter _router;
  StreamSubscription<Map<String, dynamic>>? _openedSubscription;
  StreamSubscription<ForegroundNotificationContent>? _foregroundSubscription;
  Timer? _expiryTimer;
  String? _pendingRoute;
  DateTime? _pendingSince;

  @override
  void initState() {
    super.initState();
    _router = ref.read(routerProvider);
    // Router đổi màn thì xét lại (vd. splash vừa chuyển sang /home).
    _router.routerDelegate.addListener(_evaluate);

    // Thông báo cục bộ (nhắc ngày giỗ, thông báo khi app mở) dùng được cả khi
    // Firebase lỗi, nên khởi tạo trước và KHÔNG phụ thuộc Firebase.
    final local = ref.read(localNotificationServiceProvider);
    unawaited(_startLocalNotifications(local));

    if (!ref.read(firebaseReadyProvider)) {
      return;
    }
    final messaging = ref.read(pushMessagingServiceProvider);
    _openedSubscription = messaging.openedMessageData.listen(_onTap);
    _foregroundSubscription = local.foregroundContents.listen(_onForeground);
    unawaited(_checkInitialMessage(messaging));
  }

  Future<void> _checkInitialMessage(PushMessagingService service) async {
    try {
      final data = await service.initialMessageData();
      _onTap(data);
    } catch (error) {
      debugPrint('Không đọc được thông báo đã mở app: $error');
    }
  }

  Future<void> _startLocalNotifications(LocalNotificationService local) async {
    try {
      await local.initialize(onTap: _onLocalTap);
      _onLocalTap(await local.launchPayload());
    } catch (error) {
      debugPrint('Không khởi tạo được thông báo cục bộ: $error');
    }
  }

  /// Bấm thông báo cục bộ: payload chính là đích, vẫn qua danh sách cho phép.
  void _onLocalTap(String? payload) {
    _onTap(payload == null ? null : <String, dynamic>{'route': payload});
  }

  /// Nhận thông báo FCM khi app đang mở: hiện cục bộ và làm mới danh sách.
  void _onForeground(ForegroundNotificationContent content) {
    if (!mounted || !ref.read(isAdminProvider)) {
      return;
    }
    ref.invalidate(pendingBundlesProvider);
    unawaited(_showLocal(content));
  }

  Future<void> _showLocal(ForegroundNotificationContent content) async {
    try {
      await ref.read(localNotificationServiceProvider).show(content);
    } catch (error) {
      debugPrint('Không hiện được thông báo cục bộ: $error');
    }
  }

  void _onTap(Map<String, dynamic>? data) {
    if (!mounted) {
      return;
    }
    final route = allowedPushRoute(data);
    if (route == null) {
      return;
    }
    _pendingRoute = route;
    _pendingSince = DateTime.now();
    _expiryTimer?.cancel();
    _expiryTimer = Timer(
      kPendingRouteMaxAge + const Duration(seconds: 1),
      _evaluate,
    );
    _evaluate();
  }

  void _clearPending() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _pendingRoute = null;
    _pendingSince = null;
  }

  void _evaluate() {
    final route = _pendingRoute;
    final since = _pendingSince;
    if (!mounted || route == null || since == null) {
      return;
    }

    final action = decidePendingRoute(
      route: route,
      isAdmin: ref.read(isAdminProvider),
      currentPath: _router.routerDelegate.currentConfiguration.uri.path,
      age: DateTime.now().difference(since),
    );

    switch (action) {
      case PendingRouteAction.wait:
        return;
      case PendingRouteAction.drop:
        _clearPending();
      case PendingRouteAction.open:
        _clearPending();
        // Đợi hết khung hình hiện tại rồi mới chuyển, tránh đổi màn lúc đang dựng.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(_router.push<void>(route));
          }
        });
    }
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_evaluate);
    _openedSubscription?.cancel();
    _foregroundSubscription?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Quyền admin được xác nhận xong (thường chậm hơn splash) thì xét lại.
    ref.listen<bool>(isAdminProvider, (previous, next) => _evaluate());
    return widget.child;
  }
}