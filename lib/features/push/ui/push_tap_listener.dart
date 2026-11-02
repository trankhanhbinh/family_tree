import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:familytree/core/router/app_router.dart';
import 'package:familytree/features/auth/data/admin_provider.dart';
import 'package:familytree/features/push/data/firebase_ready_provider.dart';
import 'package:familytree/features/push/data/push_messaging_service.dart';
import 'package:familytree/features/push/domain/push_route_rules.dart';

/// Bọc ngoài AdminShell (qua builder của MaterialApp.router).
/// Khi admin bấm thông báo (app đang ở nền hoặc đã tắt hẳn) thì nhớ đích,
/// đợi qua splash và đợi xác nhận quyền admin, rồi mở màn đề xuất.
class PushTapListener extends ConsumerStatefulWidget {
  const PushTapListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PushTapListener> createState() => _PushTapListenerState();
}

class _PushTapListenerState extends ConsumerState<PushTapListener> {
  late final GoRouter _router;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _expiryTimer;
  String? _pendingRoute;
  DateTime? _pendingSince;

  @override
  void initState() {
    super.initState();
    _router = ref.read(routerProvider);
    // Router đổi màn thì xét lại (vd. splash vừa chuyển sang /home).
    _router.routerDelegate.addListener(_evaluate);

    if (!ref.read(firebaseReadyProvider)) {
      return;
    }
    final service = ref.read(pushMessagingServiceProvider);
    _subscription = service.openedMessageData.listen(_onTap);
    unawaited(_checkInitialMessage(service));
  }

  Future<void> _checkInitialMessage(PushMessagingService service) async {
    try {
      final data = await service.initialMessageData();
      _onTap(data);
    } catch (error) {
      debugPrint('Không đọc được thông báo đã mở app: $error');
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
    _subscription?.cancel();
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