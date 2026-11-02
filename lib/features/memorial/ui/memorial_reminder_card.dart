import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/core/ui/choice_dialog.dart';
import 'package:familytree/features/auth/data/admin_provider.dart';
import 'package:familytree/features/memorial/data/memorial_reminder_controller.dart';
import 'package:familytree/features/memorial/domain/memorial_reminders.dart';
import 'package:familytree/features/memorial/domain/upcoming_memorials.dart';
import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';

String _two(int value) => value.toString().padLeft(2, '0');

/// Giờ nhắc dạng 20:30.
String _reminderTimeLabel() {
  return '${_two(kMemorialReminderHour)}:${_two(kMemorialReminderMinute)}';
}

/// Thẻ công tắc "Nhắc ngày giỗ" ở đầu màn Ngày giỗ. Ai cũng dùng được.
/// Admin có thêm nút thử thông báo.
class MemorialReminderCard extends ConsumerStatefulWidget {
  const MemorialReminderCard({super.key});

  @override
  ConsumerState<MemorialReminderCard> createState() =>
      _MemorialReminderCardState();
}

class _MemorialReminderCardState extends ConsumerState<MemorialReminderCard> {
  bool _loading = true;
  bool _enabled = false;

  /// Đã bật nhưng thông báo của app đang bị tắt trong Cài đặt của máy.
  bool _blocked = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  List<Person> _people() {
    return ref.read(treeDataProvider).value?.people ?? <Person>[];
  }

  Future<void> _load() async {
    final controller = ref.read(memorialReminderControllerProvider);
    final enabled = await controller.isEnabled();
    var blocked = false;
    if (enabled) {
      blocked = !await controller.notificationsAllowed();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _enabled = enabled;
      _blocked = blocked;
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      if (value) {
        await _turnOn();
      } else {
        await _turnOff();
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _turnOn() async {
    // Nút chính = "Để sau" vì đóng hộp thoại ra ngoài được tính là nút chính:
    // lỡ chạm ra ngoài thì chỉ là bỏ qua, không gây hại.
    final later = await showChoiceDialog(
      context,
      title: 'Bật nhắc ngày giỗ?',
      message: 'Trước ngày giỗ $kMemorialReminderLeadDays ngày, điện thoại sẽ '
          'nhắc bạn vào lúc ${_reminderTimeLabel()}. Thông báo chỉ ghi ngày '
          'giỗ, không ghi tên. Sau khi bấm “Bật nhắc”, máy có thể hỏi thêm '
          'một lần, bạn hãy chọn “Cho phép”.',
      primaryLabel: 'Để sau',
      secondaryLabel: 'Bật nhắc',
    );
    if (later || !mounted) {
      return;
    }

    final outcome =
        await ref.read(memorialReminderControllerProvider).enable(_people());
    if (!mounted) {
      return;
    }

    switch (outcome.result) {
      case MemorialReminderEnableResult.enabled:
        setState(() {
          _enabled = true;
          _blocked = false;
        });
        await showMessageDialog(
          context,
          title: 'Đã bật nhắc ngày giỗ',
          message: outcome.scheduledCount > 0
              ? 'Đã hẹn ${outcome.scheduledCount} lần nhắc cho các ngày giỗ '
                  'sắp tới. Mỗi lần nhắc báo trước $kMemorialReminderLeadDays '
                  'ngày, lúc ${_reminderTimeLabel()}.'
              : 'Hiện chưa có ngày giỗ nào cần nhắc trong '
                  '$kMemorialLookaheadDays ngày tới. Ứng dụng sẽ tự hẹn khi '
                  'tới gần, bạn hãy thỉnh thoảng mở ứng dụng.',
          icon: Icons.notifications_active_outlined,
        );
      case MemorialReminderEnableResult.denied:
        setState(() => _enabled = false);
        await showMessageDialog(
          context,
          title: 'Chưa bật được nhắc ngày giỗ',
          message: 'Để nhận nhắc, hãy mở Cài đặt của máy, vào Ứng dụng, chọn '
              'familytree, chọn Thông báo rồi bật lên. Sau đó quay lại đây '
              'bật công tắc.',
          icon: Icons.notifications_off_outlined,
        );
      case MemorialReminderEnableResult.failed:
        setState(() => _enabled = false);
        await showMessageDialog(
          context,
          title: 'Chưa bật được nhắc ngày giỗ',
          message: 'Có lỗi khi hẹn lịch nhắc. Bạn vui lòng thử lại sau.',
          icon: Icons.error_outline,
          isError: true,
        );
    }
  }

  Future<void> _turnOff() async {
    await ref.read(memorialReminderControllerProvider).disable();
    if (!mounted) {
      return;
    }
    setState(() {
      _enabled = false;
      _blocked = false;
    });
  }

  Future<void> _sendTest() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final ok = await ref.read(memorialReminderControllerProvider).sendTest();
      if (!mounted) {
        return;
      }
      if (ok) {
        await showMessageDialog(
          context,
          title: 'Đã hẹn thông báo thử',
          message: 'Hãy thoát ra màn hình chính của điện thoại. Thông báo sẽ '
              'hiện sau khoảng 10 giây (có thể trễ tới 1 đến 2 phút nếu máy '
              'đang tiết kiệm pin).',
          icon: Icons.schedule,
        );
      } else {
        await showMessageDialog(
          context,
          title: 'Chưa hẹn được thông báo thử',
          message: 'Máy chưa cho phép thông báo, hoặc có lỗi khi hẹn. Hãy '
              'kiểm tra Cài đặt của máy, mục Thông báo của ứng dụng.',
          icon: Icons.notifications_off_outlined,
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAdmin = ref.watch(isAdminProvider);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Nhắc ngày giỗ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Báo trước $kMemorialReminderLeadDays ngày, lúc '
                '${_reminderTimeLabel()}. Chỉ ghi ngày giỗ, không ghi tên.',
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
              value: _enabled,
              onChanged: (_loading || _busy) ? null : _toggle,
            ),
            if (_enabled && _blocked)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Thông báo của ứng dụng đang bị tắt trong Cài đặt của máy '
                  'nên chưa nhắc được.',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    color: scheme.error,
                  ),
                ),
              ),
            if (isAdmin)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  height: 56,
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _sendTest,
                    icon: const Icon(Icons.science_outlined),
                    label: const Text(
                      'Thử nhắc sau 10 giây',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}