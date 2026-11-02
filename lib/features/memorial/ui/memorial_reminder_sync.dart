import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/features/memorial/data/memorial_reminder_controller.dart';
import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';

/// Bọc ngoài app (qua builder của MaterialApp.router): lập lại lịch nhắc ngày
/// giỗ mỗi khi dữ liệu cây tải xong hoặc đổi, và mỗi khi quay lại app.
/// Chỉ làm việc nếu người dùng đã bật nhắc; không bao giờ ném lỗi.
class MemorialReminderSync extends ConsumerStatefulWidget {
  const MemorialReminderSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MemorialReminderSync> createState() =>
      _MemorialReminderSyncState();
}

class _MemorialReminderSyncState extends ConsumerState<MemorialReminderSync>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(
      treeDataProvider,
      (previous, next) => _sync(next.value?.people),
      fireImmediately: true,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sync(ref.read(treeDataProvider).value?.people);
    }
  }

  void _sync(List<Person>? people) {
    if (people == null) {
      return;
    }
    unawaited(
      ref.read(memorialReminderControllerProvider).syncIfEnabled(people),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}