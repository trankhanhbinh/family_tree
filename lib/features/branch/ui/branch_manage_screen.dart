import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/core/ui/choice_dialog.dart';
import 'package:familytree/features/auth/data/admin_provider.dart';
import 'package:familytree/features/branch/data/branch_usage_repository.dart';
import 'package:familytree/features/branch/domain/branch_changes.dart';
import 'package:familytree/features/branch/domain/branch_delete_check.dart';
import 'package:familytree/features/branch/domain/branch_move.dart';
import 'package:familytree/features/branch/domain/branch_rows.dart';
import 'package:familytree/features/branch/domain/branch_rules.dart';
import 'package:familytree/features/branch/domain/branch_usage.dart';
import 'package:familytree/features/branch/ui/branch_picker_sheet.dart';
import 'package:familytree/features/person/domain/branch_path.dart';
import 'package:familytree/features/proposals/domain/request_draft.dart';
import 'package:familytree/features/proposals/ui/submit_changes.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';
import 'package:familytree/features/tree/domain/branch.dart';

/// /admin/branches: danh sách chi/nhánh thụt lề, chạm một chi để thao tác.
class BranchManageScreen extends ConsumerWidget {
  const BranchManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý chi/nhánh')),
      body: SafeArea(
        bottom: false,
        child: isAdmin
            ? const _BranchBody()
            : const _CenterMessage(
                'Chỉ quản trị viên mới quản lý được chi/nhánh.',
              ),
      ),
      bottomNavigationBar: isAdmin
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: () => context.push('/admin/branches/new'),
                    child: const Text(
                      'Thêm chi gốc',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _BranchBody extends ConsumerWidget {
  const _BranchBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treeAsync = ref.watch(treeDataProvider);
    final usageAsync = ref.watch(branchUsageProvider);
    final tree = treeAsync.value;
    final usage = usageAsync.value;

    if (tree == null || usage == null) {
      if (treeAsync.hasError || usageAsync.hasError) {
        return _ErrorView(
          onRetry: () {
            ref.invalidate(treeDataProvider);
            ref.invalidate(branchUsageProvider);
          },
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    final rows = buildBranchRows(branches: tree.branches, usage: usage);
    if (rows.isEmpty) {
      return const _CenterMessage(
        'Chưa có chi/nhánh nào.\n'
        'Bấm "Thêm chi gốc" để tạo chi đầu tiên.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Chạm vào một chi để đổi tên, chuyển chi, thêm chi con hoặc xóa chi.',
            style: TextStyle(fontSize: 16, height: 1.4),
          ),
        ),
        for (final row in rows)
          _BranchTile(
            row: row,
            onTap: () => _showBranchActions(
              context,
              ref,
              branch: row.branch,
              branches: tree.branches,
              usage: usage,
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _BranchTile extends StatelessWidget {
  const _BranchTile({required this.row, required this.onTap});

  final BranchRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final indentLevel = row.depth > 6 ? 6 : row.depth;
    final description = row.branch.description;

    return Padding(
      padding: EdgeInsets.only(left: indentLevel * 20.0, bottom: 8),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.branch.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (description != null && description.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${row.livingCount} người',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CenterMessage extends StatelessWidget {
  const _CenterMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, height: 1.4),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

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
              'Không tải được danh sách chi.\n'
              'Hãy kiểm tra mạng rồi thử lại.',
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bảng thao tác cho một chi.
Future<void> _showBranchActions(
  BuildContext context,
  WidgetRef ref, {
  required Branch branch,
  required List<Branch> branches,
  required BranchUsage usage,
}) async {
  final path = branchPathOf(branch.id, branches);
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  path ?? branch.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              _ActionTile(
                title: 'Đổi tên',
                subtitle: 'Sửa tên và mô tả của chi này',
                onTap: () => Navigator.of(sheetContext).pop('rename'),
              ),
              const SizedBox(height: 8),
              _ActionTile(
                title: 'Chuyển sang chi khác',
                subtitle: 'Đưa chi này cùng các nhánh con vào chi khác',
                onTap: () => Navigator.of(sheetContext).pop('move'),
              ),
              const SizedBox(height: 8),
              _ActionTile(
                title: 'Thêm chi con',
                subtitle: 'Tạo một nhánh nhỏ bên trong chi này',
                onTap: () => Navigator.of(sheetContext).pop('add-child'),
              ),
              const SizedBox(height: 8),
              _ActionTile(
                title: 'Xóa chi',
                subtitle: 'Chỉ xóa được khi chi đã trống',
                onTap: () => Navigator.of(sheetContext).pop('delete'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 56,
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text(
                    'Đóng',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (choice == null || !context.mounted) {
    return;
  }
  if (choice == 'rename') {
    context.push('/admin/branches/${branch.id}/edit');
  } else if (choice == 'add-child') {
    context.push('/admin/branches/new?parent=${branch.id}');
  } else if (choice == 'move') {
    await _moveBranch(
      context,
      ref,
      branch: branch,
      branches: branches,
      usage: usage,
    );
  } else if (choice == 'delete') {
    await _deleteBranch(
      context,
      ref,
      branch: branch,
      branches: branches,
      usage: usage,
    );
  }
}

/// Chọn chi cha mới, kiểm tra, xác nhận rồi lưu.
Future<void> _moveBranch(
  BuildContext context,
  WidgetRef ref, {
  required Branch branch,
  required List<Branch> branches,
  required BranchUsage usage,
}) async {
  // Không cho chọn chính nó và các chi con cháu của nó.
  final excluded = <String>{branch.id, ...descendantIdsOf(branch.id, branches)};
  final rows = buildBranchRows(
    branches: branches,
    usage: usage,
    excludeIds: excluded,
  );

  final pick = await showBranchPickerSheet(
    context,
    title: 'Chuyển "${branch.name}" vào chi nào?',
    rows: rows,
    currentId: branch.parentBranchId,
    rootIsCurrent: branch.parentBranchId == null,
    allowRoot: true,
  );
  if (pick == null || !context.mounted) {
    return;
  }
  final newParentId = pick.branchId;

  final error = validateBranchMoveTarget(
    branch: branch,
    newParentId: newParentId,
    branches: branches,
  );
}
/// Xóa chi: chi chưa trống thì mở màn giải thích; chi trống thì xác nhận rồi xóa.
Future<void> _deleteBranch(
  BuildContext context,
  WidgetRef ref, {
  required Branch branch,
  required List<Branch> branches,
  required BranchUsage usage,
}) async {
  final blockers = checkBranchDelete(
    branchId: branch.id,
    branches: branches,
    usage: usage,
  );
  if (!blockers.canDelete) {
    context.push('/admin/branches/${branch.id}/why-not-delete');
    return;
  }

  // Nút chính là lựa chọn AN TOÀN ("Giữ lại"); chạm ra ngoài = giữ lại.
  final keep = await showChoiceDialog(
    context,
    title: 'Xóa chi này?',
    message: 'Chi "${branch.name}" đang trống. '
        'Sau khi xóa sẽ không hoàn lại được.',
    primaryLabel: 'Giữ lại',
    secondaryLabel: 'Xóa chi',
  );
  if (keep || !context.mounted) {
    return;
  }

  SubmitOutcome? outcome;
  try {
    outcome = await submitChanges(
      context,
      ref,
      drafts: [
        RequestDraft(
          entityType: kEntityBranch,
          action: kActionDelete,
          entityId: branch.id,
          payload: const <String, dynamic>{},
        ),
      ],
    );
  } catch (e) {
    if (!context.mounted) {
      return;
    }
    await showErrorDialog(context, e);
    return;
  }
  if (!context.mounted || outcome != SubmitOutcome.saved) {
    return;
  }
  await showMessageDialog(
    context,
    title: 'Đã xóa chi',
    message: 'Chi "${branch.name}" đã được xóa.',
  );
}