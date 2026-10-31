import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/features/push/data/admin_device_repository.dart';
import 'package:familytree/features/push/data/firebase_ready_provider.dart';
import 'package:familytree/features/push/data/push_fid_store.dart';
import 'package:familytree/features/push/data/push_messaging_service.dart';
import 'package:familytree/features/push/domain/push_rules.dart';

/// Điều phối thông báo đẩy của admin: xin quyền, đăng ký, lưu FID lên server,
/// nhớ FID trên máy và xóa khi đăng xuất.
/// Các hàm "âm thầm" không bao giờ ném lỗi, chỉ ghi log.
class PushDeviceController {
  PushDeviceController({
    required this._firebaseReady,
    required this._messaging,
    required this._repository,
    required this._fidStore,
  });

  final bool _firebaseReady;
  final PushMessagingService _messaging;
  final AdminDeviceRepository _repository;
  final PushFidStore _fidStore;

  static const Duration _removeTimeout = Duration(seconds: 5);

  StreamSubscription<String>? _fidSubscription;
  Future<void>? _registering;
  String? _lastSavedFid;

  // Tăng mỗi lần xóa thiết bị: việc đăng ký đang dở thấy số đổi thì bỏ, không
  // lưu lại dòng vừa xóa.
  int _epoch = 0;

  /// Có nên hiện hộp thoại xin bật thông báo sau khi đăng nhập không.
  Future<bool> needsLoginPrompt() async {
    if (!_firebaseReady) {
      return false;
    }
    try {
      final permission = await _messaging.currentPermission();
      return shouldAskAtLogin(
        firebaseReady: _firebaseReady,
        permission: permission,
      );
    } catch (error) {
      debugPrint('Không đọc được quyền thông báo (bỏ qua): $error');
      return false;
    }
  }

  /// Đăng ký âm thầm nếu quyền đã được cấp. Trả về true nếu đã đăng ký.
  Future<bool> registerSilentlyIfGranted({required bool isAdmin}) async {
    if (!_firebaseReady || !isAdmin) {
      return false;
    }
    try {
      final permission = await _messaging.currentPermission();
      if (!shouldRegisterSilently(
        firebaseReady: _firebaseReady,
        isAdmin: isAdmin,
        permission: permission,
      )) {
        return false;
      }
      await _registerAndSave();
      return true;
    } catch (error) {
      debugPrint('Đăng ký thông báo âm thầm thất bại (bỏ qua): $error');
      return false;
    }
  }

  /// Admin vừa bấm "Bật thông báo": xin quyền rồi đăng ký và lưu.
  Future<PushEnableResult> enable() async {
    if (!_firebaseReady) {
      return PushEnableResult.unavailable;
    }
    try {
      final permission = await _messaging.requestPermission();
      if (permission != PushPermission.granted) {
        return PushEnableResult.denied;
      }
    } catch (error) {
      debugPrint('Không xin được quyền thông báo: $error');
      return PushEnableResult.unavailable;
    }
    try {
      await _registerAndSave();
      return PushEnableResult.enabled;
    } catch (error) {
      debugPrint('Đăng ký hoặc lưu thiết bị thất bại: $error');
      return PushEnableResult.saveFailed;
    }
  }

  /// Gọi TRƯỚC khi đăng xuất (lúc còn là admin). Không bao giờ ném lỗi.
  /// Lỗi mạng thì vẫn cho đăng xuất; dòng thừa sẽ được dọn khi FCM báo FID
  /// không còn tồn tại (5F-3).
  Future<void> removeThisDevice() async {
    _epoch++;
    await _stopWatching();
    try {
      final fid = _lastSavedFid ?? await _fidStore.read();
      if (fid != null && fid.isNotEmpty) {
        await _repository.deleteDevice(fid, timeout: _removeTimeout);
      }
    } catch (error) {
      debugPrint('Không xóa được thiết bị admin (bỏ qua): $error');
    }
    _lastSavedFid = null;
    await _fidStore.clear();
  }

  void dispose() {
    unawaited(_stopWatching());
  }

  Future<void> _registerAndSave() {
    return _registering ??= _doRegisterAndSave().whenComplete(() {
      _registering = null;
    });
  }

  Future<void> _doRegisterAndSave() async {
    final epoch = _epoch;
    final fid = await _messaging.registerAndGetFid();
    if (epoch != _epoch) {
      return;
    }
    await _saveFid(fid);
    if (epoch != _epoch) {
      return;
    }
    _watchFidChanges();
  }

  Future<void> _saveFid(String fid) async {
    await _repository.saveDevice(fid);
    _lastSavedFid = fid;
    await _fidStore.write(fid);
  }

  void _watchFidChanges() {
    if (_fidSubscription != null) {
      return;
    }
    _fidSubscription = _messaging.fidChanges.listen(
      (fid) {
        unawaited(_onFidChanged(fid));
      },
      onError: (Object error) {
        debugPrint('Luồng FID báo lỗi (bỏ qua): $error');
      },
    );
  }

  Future<void> _onFidChanged(String fid) async {
    if (fid == _lastSavedFid) {
      return;
    }
    try {
      await _saveFid(fid);
    } catch (error) {
      debugPrint('Không lưu được FID mới (bỏ qua): $error');
    }
  }

  Future<void> _stopWatching() async {
    final subscription = _fidSubscription;
    _fidSubscription = null;
    await subscription?.cancel();
  }
}

final pushDeviceControllerProvider = Provider<PushDeviceController>((ref) {
  final controller = PushDeviceController(
    firebaseReady: ref.watch(firebaseReadyProvider),
    messaging: ref.watch(pushMessagingServiceProvider),
    repository: ref.watch(adminDeviceRepositoryProvider),
    fidStore: ref.watch(pushFidStoreProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});