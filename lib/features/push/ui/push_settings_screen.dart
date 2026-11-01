import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/core/ui/choice_dialog.dart';
import 'package:familytree/features/auth/data/admin_provider.dart';
import 'package:familytree/features/push/data/push_device_controller.dart';
import 'package:familytree/features/push/data/push_status_provider.dart';
import 'package:familytree/features/push/domain/push_rules.dart';
import 'package:familytree/features/push/ui/push_prompt.dart';

/// /admin/notifications: admin xem, bật hoặc tắt thông báo đề xuất mới
/// trên CHÍNH máy này.
class PushSettingsScreen extends ConsumerStatefulWidget {
  const PushSettingsScreen({super.key});

  @override
  ConsumerState<PushSettingsScreen> createState() =>
      _PushSettingsScreenState();
}

class _PushSettingsScreenState extends ConsumerState<PushSettingsScreen>
    with WidgetsBindingObserver {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Quay lại app từ Cài đặt của máy: đọc lại quyền để màn không bị cũ.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(pushStatusProvider);
    }
  }

  Future<T> _runBusy<T>(Future<T> Function() action) async {
    setState(() => _busy = true);
    try {
      return await action();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _enable() async {
    if (_busy) {
      return;
    }
    final controller = ref.read(pushDeviceControllerProvider);
    final result = await _runBusy(controller.enable);
    if (!mounted) {
      return;
    }
    ref.invalidate(pushStatusProvider);
    await showPushEnableResultDialog(context, result);
  }

  Future<void> _disable() async {
    if (_busy) {
      return;
    }
    // Nút chính = "Giữ nguyên" (an toàn); hành động thật ở nút phụ.
    final keep = await showChoiceDialog(
      context,
      title: 'Tắt thông báo trên máy này?',
      message: 'Máy này sẽ không báo khi có đề xuất mới nữa. '
          'Bạn có thể bật lại bất cứ lúc nào.',
      primaryLabel: 'Giữ nguyên',
      secondaryLabel: 'Tắt thông báo',
    );
    if (keep || !mounted) {
      return;
    }

    final controller = ref.read(pushDeviceControllerProvider);
    final removed = await _runBusy(controller.disable);
    if (!mounted) {
      return;
    }
    ref.invalidate(pushStatusProvider);

    if (removed) {
      await showMessageDialog(
        context,
        title: 'Đã tắt thông báo',
        message: 'Máy này sẽ không còn báo đề xuất mới. '
            'Muốn nhận lại, hãy bấm “Bật thông báo”.',
        icon: Icons.notifications_off_outlined,
      );
    } else {
      await showMessageDialog(
        context,
        title: 'Chưa tắt hết được',
        message: 'Đã tắt thông báo trên máy, nhưng chưa xóa được máy này '
            'khỏi hệ thống vì không có mạng. Máy có thể vẫn nhận thông báo. '
            'Khi có mạng, hãy bấm “Bật thông báo” rồi tắt lại.',
        icon: Icons.cloud_off_outlined,
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final statusAsync = ref.watch(pushStatusProvider);
    // Giữ dữ liệu cũ khi đang tải lại: dùng .value, không dùng .when.
    final status = statusAsync.value;

    final Widget body;
    if (!isAdmin) {
      body = const _AdminOnlyView();
    } else if (status != null) {
      body = _StatusBody(
        status: status,
        busy: _busy,
        onEnable: _enable,
        onDisable: _disable,
      );
    } else if (statusAsync.hasError) {
      body = _LoadErrorView(
        onRetry: () => ref.invalidate(pushStatusProvider),
      );
    } else {
      body = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo đề xuất mới')),
      body: SafeArea(child: body),
    );
  }
}

class _StatusInfo {
  const _StatusInfo({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.isDisableAction = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final bool isDisableAction;
}

_StatusInfo _infoFor(PushStatus status) {
  switch (status) {
    case PushStatus.enabled:
      return const _StatusInfo(
        icon: Icons.notifications_active_outlined,
        title: 'Đang bật',
        message: 'Khi có người gửi đề xuất mới, điện thoại này sẽ báo '
            'cho bạn biết.',
        actionLabel: 'Tắt thông báo trên máy này',
        isDisableAction: true,
      );
    case PushStatus.notSaved:
      return const _StatusInfo(
        icon: Icons.cloud_off_outlined,
        title: 'Chưa lưu được',
        message: 'Máy đã cho phép thông báo nhưng chưa lưu được lên hệ '
            'thống, nên chưa nhận được thông báo. Hãy kiểm tra mạng rồi '
            'bấm “Thử lại”.',
        actionLabel: 'Thử lại',
      );
    case PushStatus.notEnabled:
      return const _StatusInfo(
        icon: Icons.notifications_off_outlined,
        title: 'Chưa bật',
        message: 'Máy này chưa được cho phép hiện thông báo. '
            'Bấm nút bên dưới để bật.',
        actionLabel: 'Bật thông báo',
      );
    case PushStatus.turnedOff:
      return const _StatusInfo(
        icon: Icons.notifications_off_outlined,
        title: 'Đã tắt',
        message: 'Bạn đã tắt thông báo trên máy này. '
            'Muốn nhận lại thì bấm “Bật thông báo”.',
        actionLabel: 'Bật thông báo',
      );
    case PushStatus.unavailable:
      return const _StatusInfo(
        icon: Icons.block_outlined,
        title: 'Không dùng được',
        message: 'Máy này chưa dùng được thông báo đẩy. '
            'Bạn vẫn dùng ứng dụng bình thường.',
      );
  }
}

class _StatusBody extends StatelessWidget {
  const _StatusBody({
    required this.status,
    required this.busy,
    required this.onEnable,
    required this.onDisable,
  });

  final PushStatus status;
  final bool busy;
  final VoidCallback onEnable;
  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final info = _infoFor(status);
    final iconColor = switch (status) {
      PushStatus.enabled => scheme.primary,
      PushStatus.notSaved => scheme.error,
      _ => scheme.onSurfaceVariant,
    };
    final actionLabel = info.actionLabel;
    final actionText = Text(
      busy ? 'Đang xử lý...' : (actionLabel ?? ''),
      style: const TextStyle(fontSize: 18),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(info.icon, size: 56, color: iconColor),
                  const SizedBox(height: 12),
                  Text(
                    info.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    info.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: info.isDisableAction
                  ? OutlinedButton(
                      onPressed: busy ? null : onDisable,
                      child: actionText,
                    )
                  : FilledButton(
                      onPressed: busy ? null : onEnable,
                      child: actionText,
                    ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Mỗi điện thoại quản trị bật hoặc tắt riêng. Thông báo chỉ cho '
            'biết có đề xuất mới, không có tên người trong dòng họ.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              height: 1.4,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _AdminOnlyView extends StatelessWidget {
  const _AdminOnlyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Chỉ quản trị viên mới quản lý được thông báo.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, height: 1.4),
        ),
      ),
    );
  }
}

class _LoadErrorView extends StatelessWidget {
  const _LoadErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Chưa đọc được trạng thái thông báo.\nHãy thử lại.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, height: 1.4),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: onRetry,
                child: const Text('Thử lại', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}