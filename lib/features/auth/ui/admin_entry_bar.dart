import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:familytree/core/ui/choice_dialog.dart';
import 'package:familytree/features/auth/data/admin_provider.dart';
import 'package:familytree/features/review/data/review_repository.dart';

/// Thanh cao 56 ở cuối màn hình cây.
/// Người thường: nút "Quản trị viên". Admin: "Duyệt đề xuất (N)" + "Đăng xuất".
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final notifier = ref.read(isAdminProvider.notifier);
    final pendingCount = ref.watch(pendingCountProvider);
    final scheme = Theme.of(context).colorScheme;

    final Widget content;
    if (isAdmin) {
      final reviewLabel = (pendingCount == null || pendingCount == 0)
          ? 'Duyệt đề xuất'
          : 'Duyệt đề xuất ($pendingCount)';
      content = Row(
        children: [
          Expanded(
            child: TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                foregroundColor: scheme.onSurface,
              ),
              onPressed: () => context.push('/admin/requests'),
              child: Text(
                reviewLabel,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const VerticalDivider(width: 1, indent: 10, endIndent: 10),
          Expanded(
            child: TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                foregroundColor: scheme.error,
              ),
              onPressed: () => _confirmLogout(context, notifier),
              child: const Text(
                'Đăng xuất',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      );
    } else {
      content = TextButton.icon(
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          foregroundColor: scheme.onSurface,
        ),
        onPressed: () => context.push('/admin-login'),
        icon: const Icon(Icons.admin_panel_settings_outlined, size: 24),
        label: const Text(
          'Quản trị viên',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      );
    }

    return Material(
      color: scheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: SizedBox(height: 56, child: content),
      ),
    );
  }
}