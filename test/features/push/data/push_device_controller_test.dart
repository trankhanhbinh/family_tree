import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/push/data/admin_device_repository.dart';
import 'package:familytree/features/push/data/push_device_controller.dart';
import 'package:familytree/features/push/data/push_fid_store.dart';
import 'package:familytree/features/push/data/push_messaging_service.dart';
import 'package:familytree/features/push/domain/push_rules.dart';

class _FakeRepository implements AdminDeviceRepository {
  final List<String> saved = [];
  final List<String> deleted = [];
  final List<Duration> deleteTimeouts = [];
  Object? saveError;
  Object? deleteError;

  @override
  Future<void> saveDevice(
    String fid, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final error = saveError;
    if (error != null) {
      throw error;
    }
    saved.add(fid);
  }

  @override
  Future<void> deleteDevice(
    String fid, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    deleteTimeouts.add(timeout);
    final error = deleteError;
    if (error != null) {
      throw error;
    }
    deleted.add(fid);
  }
}

class _FakeMessaging implements PushMessagingService {
  PushPermission current = PushPermission.granted;
  PushPermission afterRequest = PushPermission.granted;
  String fid = 'fid-1';
  Completer<void>? registerGate;
  int registerCalls = 0;
  int requestCalls = 0;
  final StreamController<String> changes = StreamController<String>.broadcast();

  @override
  Future<PushPermission> currentPermission() async => current;

  @override
  Future<PushPermission> requestPermission() async {
    requestCalls++;
    return afterRequest;
  }

  @override
  Future<String> registerAndGetFid({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    registerCalls++;
    final gate = registerGate;
    if (gate != null) {
      await gate.future;
    }
    return fid;
  }

  @override
  Stream<String> get fidChanges => changes.stream;
}

class _FakeFidStore implements PushFidStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String fid) async {
    value = fid;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

void main() {
  late _FakeRepository repo;
  late _FakeMessaging messaging;
  late _FakeFidStore store;

  setUp(() {
    repo = _FakeRepository();
    messaging = _FakeMessaging();
    store = _FakeFidStore();
  });

  tearDown(() async {
    await messaging.changes.close();
  });

  PushDeviceController makeController({bool firebaseReady = true}) {
    return PushDeviceController(
      firebaseReady: firebaseReady,
      messaging: messaging,
      repository: repo,
      fidStore: store,
    );
  }

  group('enable', () {
    test('đã cấp quyền thì lưu FID, nhớ FID và trả về enabled', () async {
      final controller = makeController();

      final result = await controller.enable();

      expect(result, PushEnableResult.enabled);
      expect(messaging.requestCalls, 1);
      expect(repo.saved, ['fid-1']);
      expect(store.value, 'fid-1');
    });

    test('bị từ chối thì không đăng ký, không lưu', () async {
      messaging.afterRequest = PushPermission.denied;
      final controller = makeController();

      final result = await controller.enable();

      expect(result, PushEnableResult.denied);
      expect(messaging.registerCalls, 0);
      expect(repo.saved, isEmpty);
    });

    test('lưu lỗi thì trả về saveFailed và không nhớ FID', () async {
      repo.saveError = Exception('mất mạng');
      final controller = makeController();

      final result = await controller.enable();

      expect(result, PushEnableResult.saveFailed);
      expect(store.value, isNull);
    });

    test('Firebase chưa sẵn sàng thì không làm gì', () async {
      final controller = makeController(firebaseReady: false);

      final result = await controller.enable();

      expect(result, PushEnableResult.unavailable);
      expect(messaging.requestCalls, 0);
      expect(messaging.registerCalls, 0);
    });
  });

  group('registerSilentlyIfGranted', () {
    test('không phải admin thì không làm gì', () async {
      final controller = makeController();

      final result = await controller.registerSilentlyIfGranted(isAdmin: false);

      expect(result, isFalse);
      expect(messaging.registerCalls, 0);
    });

    test('chưa cấp quyền thì không đăng ký', () async {
      messaging.current = PushPermission.denied;
      final controller = makeController();

      final result = await controller.registerSilentlyIfGranted(isAdmin: true);

      expect(result, isFalse);
      expect(messaging.registerCalls, 0);
      expect(repo.saved, isEmpty);
    });

    test('đã cấp quyền thì đăng ký và lưu FID', () async {
      final controller = makeController();

      final result = await controller.registerSilentlyIfGranted(isAdmin: true);

      expect(result, isTrue);
      expect(repo.saved, ['fid-1']);
      expect(store.value, 'fid-1');
    });

    test('lưu lỗi thì không ném ra ngoài, trả về false', () async {
      repo.saveError = Exception('mất mạng');
      final controller = makeController();

      final result = await controller.registerSilentlyIfGranted(isAdmin: true);

      expect(result, isFalse);
    });

    test('gọi đồng thời hai lần chỉ đăng ký một lần', () async {
      messaging.registerGate = Completer<void>();
      final controller = makeController();

      final first = controller.registerSilentlyIfGranted(isAdmin: true);
      final second = controller.registerSilentlyIfGranted(isAdmin: true);
      await pumpEventQueue();
      messaging.registerGate!.complete();
      await Future.wait([first, second]);

      expect(messaging.registerCalls, 1);
      expect(repo.saved.length, 1);
    });
  });

  group('theo dõi FID đổi', () {
    test('FID mới thì lưu, FID trùng thì bỏ qua', () async {
      final controller = makeController();
      await controller.enable();

      messaging.changes.add('fid-1');
      messaging.changes.add('fid-2');
      await pumpEventQueue();

      expect(repo.saved, ['fid-1', 'fid-2']);
      expect(store.value, 'fid-2');
    });
  });

  group('removeThisDevice', () {
    test('xóa theo FID đã nhớ với tối đa 5 giây rồi xóa FID nhớ', () async {
      final controller = makeController();
      await controller.enable();

      await controller.removeThisDevice();

      expect(repo.deleted, ['fid-1']);
      expect(repo.deleteTimeouts, [const Duration(seconds: 5)]);
      expect(store.value, isNull);
    });

    test('chỉ có FID trong kho (vừa mở app) vẫn xóa được', () async {
      store.value = 'fid-old';
      final controller = makeController();

      await controller.removeThisDevice();

      expect(repo.deleted, ['fid-old']);
      expect(store.value, isNull);
    });

    test('lỗi xóa không ném ra ngoài và vẫn xóa FID nhớ', () async {
      store.value = 'fid-old';
      repo.deleteError = Exception('mất mạng');
      final controller = makeController();

      await controller.removeThisDevice();

      expect(repo.deleted, isEmpty);
      expect(store.value, isNull);
    });

    test('không có FID nào thì không gọi xóa', () async {
      final controller = makeController();

      await controller.removeThisDevice();

      expect(repo.deleteTimeouts, isEmpty);
    });

    test('xóa giữa lúc đang đăng ký thì không lưu nữa', () async {
      messaging.registerGate = Completer<void>();
      final controller = makeController();

      final silent = controller.registerSilentlyIfGranted(isAdmin: true);
      await pumpEventQueue();
      await controller.removeThisDevice();
      messaging.registerGate!.complete();
      await silent;

      expect(repo.saved, isEmpty);
      expect(messaging.changes.hasListener, isFalse);
    });

    test('dừng theo dõi FID đổi', () async {
      final controller = makeController();
      await controller.enable();
      await controller.removeThisDevice();

      messaging.changes.add('fid-9');
      await pumpEventQueue();

      expect(repo.saved, ['fid-1']);
    });
  });

  group('needsLoginPrompt', () {
    test('đã cấp quyền thì không cần hỏi', () async {
      final controller = makeController();

      expect(await controller.needsLoginPrompt(), isFalse);
    });

    test('đã từ chối hoặc chưa hỏi thì cần hỏi', () async {
      final controller = makeController();

      messaging.current = PushPermission.denied;
      expect(await controller.needsLoginPrompt(), isTrue);

      messaging.current = PushPermission.notDetermined;
      expect(await controller.needsLoginPrompt(), isTrue);
    });

    test('Firebase chưa sẵn sàng thì không hỏi', () async {
      messaging.current = PushPermission.notDetermined;
      final controller = makeController(firebaseReady: false);

      expect(await controller.needsLoginPrompt(), isFalse);
    });
  });
}