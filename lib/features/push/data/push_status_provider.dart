import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/features/push/data/push_device_controller.dart';
import 'package:familytree/features/push/domain/push_rules.dart';

/// Trạng thái thông báo của máy này (đọc từ bản ghi trên máy, không hỏi
/// server). Tự hủy khi rời màn; gọi invalidate sau mỗi thao tác để tải lại.
final pushStatusProvider = FutureProvider.autoDispose<PushStatus>(
  (ref) => ref.watch(pushDeviceControllerProvider).status(),
  retry: (retryCount, error) => null,
);