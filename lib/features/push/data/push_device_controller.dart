import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/features/push/data/admin_device_repository.dart';
import 'package:familytree/features/push/data/firebase_ready_provider.dart';
import 'package:familytree/features/push/data/push_fid_store.dart';
import 'package:familytree/features/push/data/push_messaging_service.dart';
import 'package:familytree/features/push/domain/push_rules.dart';

/// Điều phối thông báo đẩy của admin: xin quyền, đăng ký, lưu FID lên server,
/// nhớ FID trên máy và xóa khi đăng xuất hoặc khi admin tắt thông báo.
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

  /// Trạng thái thông báo của máy này, suy từ bản ghi trên máy (không hỏi
  /// server). Không bao giờ ném lỗi.
  Future<PushStatus> status() async {
    final optedOut = await _fidStore.isOptedOut();
    var permission = PushPermission.notDetermined;
    if (_firebaseReady) {
      try {
        permission = await _messaging.currentPermission();
      } catch (error) {
        debugPrint('Không đọc được quyền thông báo (bỏ qua): $error');
      }
    }
    final fid = _lastSavedFid ?? await _fidStore.read();
    return pushStatusFrom(
      firebaseReady: _firebaseReady,
      permission: permission,
      hasSavedFid: fid != null && fid.isNotEmpty,
      optedOut: optedOut,
    );
  }

  /// Có nên hiện hộp thoại xin bật thông báo sau khi đăng nhập không.
  /// Admin đã tắt thông báo trên máy này thì không hỏi lại.
  Future<bool> needsLoginPrompt() async {
    if (!_firebaseReady) {
      return false;
    }
    if (await _fidStore.isOptedOut()) {
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
  /// Admin đã tắt thông báo trên máy này thì không đăng ký.
  Future<bool> registerSilentlyIfGranted({required bool isAdmin}) async {
    if (!_firebaseReady || !isAdmin) {
      return false;
    }
    if (await _fidStore.isOptedOut()) {
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

  /// Admin vừa bấm "Bật thông báo": xóa cờ đã tắt, xin quyền rồi đăng ký và
  /// lưu.
  Future<PushEnableResult> enable() async {
    if (!_firebaseReady) {
      return PushEnableResult.unavailable;
    }
    await _fidStore.clearOptedOut();
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
      await flushPendingDeletes();
      return PushEnableResult.enabled;
    } catch (error) {
      debugPrint('Đăng ký hoặc lưu thiết bị thất bại: $error');
      return PushEnableResult.saveFailed;
    }
  }

  /// Admin bấm "Tắt thông báo trên máy này": ghi cờ đã tắt, rồi xóa dòng của
  /// máy này trên server và FID đã nhớ. Cờ được ghi TRƯỚC nên dù xóa server
  /// lỗi thì app cũng không tự đăng ký lại. Trả về true nếu xóa server thành
  /// công (hoặc không có gì để xóa), false nếu lỗi mạng. Không bao giờ ném
  /// lỗi.
  Future<bool> disable() async {
    await _fidStore.setOptedOut();
    return _forgetThisDevice();
  }

  /// Gọi TRƯỚC khi đăng xuất (lúc còn là admin). Không bao giờ ném lỗi.
  /// Lỗi mạng thì vẫn cho đăng xuất; dòng thừa sẽ được dọn khi FCM báo FID
  /// không còn tồn tại (5F-3). Không đụng cờ đã tắt.
  Future<void> removeThisDevice() async {
    await _forgetThisDevice();
  }

  Future<bool> _forgetThisDevice() async {
    _epoch++;
    await _stopWatching();
    var removed = true;
    String? fid;
    try {
      fid = _lastSavedFid ?? await _fidStore.read();
      if (fid != null && fid.isNotEmpty) {
        await _repository.deleteDevice(fid, timeout: _removeTimeout);
      }
    } catch (error) {
      removed = false;
      if (fid != null && fid.isNotEmpty) {
        await _fidStore.addPendingDelete(fid);
      }
      debugPrint('Không xóa được thiết bị admin (bỏ qua): $error');
    }
    _lastSavedFid = null;
    await _fidStore.clear();
    return removed;
  }

  /// Xóa các dòng admin_devices còn sót do lần xóa trước bị lỗi mạng. Chỉ chạy
  /// khi đang là admin (quyền xóa). Không bao giờ ném lỗi.
  Future<void> flushPendingDeletes() async {
    final pending = await _fidStore.readPendingDeletes();
    for (final fid in pending) {
      // FID đang dùng thì dòng đã được tạo lại: không được xóa.
      if (fid == _lastSavedFid) {
        await _fidStore.removePendingDelete(fid);
        continue;
      }
      try {
        await _repository.deleteDevice(fid, timeout: _removeTimeout);
        await _fidStore.removePendingDelete(fid);
      } catch (error) {
        debugPrint('Chưa xóa được FID chờ xóa (thử lại sau): $error');
      }
    }
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
    await _fidStore.removePendingDelete(fid);
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
