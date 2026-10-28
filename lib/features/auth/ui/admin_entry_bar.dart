import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:familytree/core/ui/choice_dialog.dart';
import 'package:familytree/features/auth/data/admin_provider.dart';
import 'package:familytree/features/review/data/review_repository.dart';

/// Thanh cao 56 ở cuối màn hình cây.
/// Người thường: "Đề xuất của tôi (N)" | "Quản trị viên".
/// Admin: "Duyệt đề xuất (N)" | "Đăng xuất".
class AdminEntryBar extends ConsumerWidget {
  const AdminEntryBar({super.key});

  Future<void> _confirmLogout(
    BuildContext context,
    AdminNotifier notifier,
  ) async {
    // Nút chính = "Ở lại" vì đóng hộp thoại ra ngoài được tính là nút chính:
    // lỡ chạm ra ngoài thì KHÔNG bị đăng xuất.
    final stay = await showChoiceDialog(
      context,
      title: 'Đăng xuất quản trị viên?',
      message: 'Bạn sẽ quay về chế độ người đóng góp. '
          'Muốn sửa trực tiếp thì phải nhập lại mã.',
      primaryLabel: 'Ở lại',
      secondaryLabel: 'Đăng xuất',
    );
    if (stay) {
      return;
    }
    await notifier.signOut();
  }

  Widget _halfButton({
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Expanded(
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          foregroundColor: color,
        ),
        onPressed: onPressed,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final notifier = ref.read(isAdminProvider.notifier);
    final pendingCount = ref.watch(pendingCountProvider);
    final myPendingCount = ref.watch(myPendingCountProvider);
    final scheme = Theme.of(context).colorScheme;

    final String leftLabel;
    final VoidCallback leftAction;
    final String rightLabel;
    final VoidCallback rightAction;
    final Color rightColor;

    if (isAdmin) {
      leftLabel = (pendingCount == null || pendingCount == 0)
          ? 'Duyệt đề xuất'
          : 'Duyệt đề xuất ($pendingCount)';
      leftAction = () => context.push('/admin/requests');
      rightLabel = 'Đăng xuất';
      rightAction = () => _confirmLogout(context, notifier);
      rightColor = scheme.error;
    } else {
      leftLabel = (myPendingCount == null || myPendingCount == 0)
          ? 'Đề xuất của tôi'
          : 'Đề xuất của tôi ($myPendingCount)';
      leftAction = () => context.push('/my-requests');
      rightLabel = 'Quản trị viên';
      rightAction = () => context.push('/admin-login');
      rightColor = scheme.onSurface;
    }

    return Material(
      color: scheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _halfButton(
                label: leftLabel,
                onPressed: leftAction,
                color: scheme.onSurface,
              ),
              const VerticalDivider(width: 1, indent: 10, endIndent: 10),
              _halfButton(
                label: rightLabel,
                onPressed: rightAction,
                color: rightColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}