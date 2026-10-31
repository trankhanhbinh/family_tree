import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/features/auth/data/admin_provider.dart';
import 'package:familytree/features/branch/data/branch_usage_repository.dart';
import 'package:familytree/features/branch/domain/branch_changes.dart';
import 'package:familytree/features/branch/domain/branch_delete_check.dart';
import 'package:familytree/features/branch/domain/branch_delete_texts.dart';
import 'package:familytree/features/branch/domain/branch_rows.dart';
import 'package:familytree/features/branch/domain/branch_rules.dart';
import 'package:familytree/features/branch/domain/branch_usage.dart';
import 'package:familytree/features/branch/ui/branch_picker_sheet.dart';
import 'package:familytree/features/person/domain/branch_path.dart';
import 'package:familytree/features/proposals/domain/request_draft.dart';
import 'package:familytree/features/proposals/ui/submit_changes.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';
import 'package:familytree/features/tree/domain/branch.dart';

/// /admin/branches/:id/why-not-delete: giải thích vì sao chi chưa xóa được
/// và cho chuyển nhanh người sang chi khác.
class BranchBlockedScreen extends ConsumerWidget {
  const BranchBlockedScreen({super.key, required this.branchId});

  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final treeAsync = ref.watch(treeDataProvider);
    final usageAsync = ref.watch(branchUsageProvider);
    final tree = treeAsync.value;
    final usage = usageAsync.value;

    Widget body;
    if (!isAdmin) {
      body = const _CenterMessage('Chỉ quản trị viên mới xem được trang này.');
    } else if (tree == null || usage == null) {
      if (treeAsync.hasError || usageAsync.hasError) {
        body = _ErrorView(
          onRetry: () {
            ref.invalidate(treeDataProvider);
            ref.invalidate(branchUsageProvider);
          },
        );
      } else {
        body = const Center(child: CircularProgressIndicator());
      }
    } else {
      Branch? branch;
      for (final b in tree.branches) {
        if (b.id == branchId) {
          branch = b;
          break;
        }
      }
      if (branch == null) {
        body = const _CenterMessage(
          'Không tìm thấy chi này (có thể đã bị xóa).',
        );
      } else {
        body = _BlockedBody(
          branch: branch,
          branches: tree.branches,
          usage: usage,
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Xóa chi này')),
      body: SafeArea(child: body),
    );
  }
}

class _BlockedBody extends ConsumerWidget {
  const _BlockedBody({
    required this.branch,
    required this.branches,
    required this.usage,
  });

  final Branch branch;
  final List<Branch> branches;
  final BranchUsage usage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final blockers = checkBranchDelete(
      branchId: branch.id,
      branches: branches,
      usage: usage,
    );
    final steps = branchBlockedSteps(blockers);
    final path = branchPathOf(branch.id, branches) ?? branch.name;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PathBox(text: 'Chi: $path'),
        const _SectionTitle('Tình trạng hiện tại'),
        if (blockers.canDelete)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Chi này đã trống nên có thể xóa được rồi.',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: () => context.pop(),
                    child: const Text(
                      'Quay lại để xóa chi',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (blockers.childBranches.isNotEmpty)
          _BlockerCard(
            title: childBranchesTitle(blockers.childBranches.length),
            body: summarizeNames(
              blockers.childBranches.map((b) => b.name).toList(),
              unit: 'chi',
            ),
          ),
        if (blockers.livingPeople.isNotEmpty)
          _BlockerCard(
            title: livingPeopleTitle(blockers.livingPeople.length),
            body: summarizeNames(
              blockers.livingPeople.map((m) => m.fullName).toList(),
            ),
            buttonLabel: moveMembersButtonLabel(blockers.livingPeople.length),
            onPressed: () => _moveMembers(
              context,
              ref,
              branch: branch,
              branches: branches,
              usage: usage,
              members: blockers.livingPeople,
              areDeleted: false,
            ),
          ),
        if (blockers.deletedPeople.isNotEmpty)
          _BlockerCard(
            title: deletedPeopleTitle(blockers.deletedPeople.length),
            body: '${summarizeNames(
              blockers.deletedPeople.map((m) => m.fullName).toList(),
            )}\n\nHọ vẫn là người đã xóa; việc chuyển chỉ đổi chi của họ.',
            buttonLabel: moveMembersButtonLabel(blockers.deletedPeople.length),
            onPressed: () => _moveMembers(
              context,
              ref,
              branch: branch,
              branches: branches,
              usage: usage,
              members: blockers.deletedPeople,
              areDeleted: true,
            ),
          ),
        if (!blockers.canDelete) ...[
          const _SectionTitle('Vì sao chưa xóa được?'),
          const Text(
            kBranchBlockedReason,
            style: TextStyle(fontSize: 17, height: 1.5),
          ),
          const _SectionTitle('Cách xử lý từng bước'),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '${i + 1}. ${steps[i]}',
                style: const TextStyle(fontSize: 17, height: 1.5),
              ),
            ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 56,
          child: OutlinedButton(
            onPressed: () => context.pop(),
            child: const Text('Đóng', style: TextStyle(fontSize: 18)),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _PathBox extends StatelessWidget {
  const _PathBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          height: 1.4,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _BlockerCard extends StatelessWidget {
  const _BlockerCard({
    required this.title,
    required this.body,
    this.buttonLabel,
    this.onPressed,
  });

  final String title;
  final String body;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(fontSize: 16, height: 1.4)),
          if (buttonLabel != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: onPressed,
                child: Text(buttonLabel!, style: const TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ],
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
              'Không tải được dữ liệu.\nHãy kiểm tra mạng rồi thử lại.',
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

/// Chuyển cả nhóm người (đang sống hoặc đã xóa) sang một chi khác, một giao dịch.
Future<void> _moveMembers(
  BuildContext context,
  WidgetRef ref, {
  required Branch branch,
  required List<Branch> branches,
  required BranchUsage usage,
  required List<BranchMember> members,
  required bool areDeleted,
}) async {
  // Lấy sẵn container: dùng được kể cả khi màn hình bị dựng lại.
  final container = ProviderScope.containerOf(context, listen: false);

  // Không cho chọn chính chi này và các chi con của nó.
  final excluded = <String>{branch.id, ...descendantIdsOf(branch.id, branches)};
  final rows = buildBranchRows(
    branches: branches,
    usage: usage,
    excludeIds: excluded,
  );
  if (rows.isEmpty) {
    await showMessageDialog(
      context,
      title: 'Chưa có chi nào để chuyển sang',
      message:
          'Hãy tạo thêm một chi khác ở màn "Quản lý chi/nhánh" rồi quay lại đây.',
    );
    return;
  }

  final pick = await showBranchPickerSheet(
    context,
    title: 'Chuyển ${members.length} người sang chi nào?',
    rows: rows,
  );
  if (pick == null || !context.mounted) {
    return;
  }
  final targetId = pick.branchId;
  if (targetId == null) {
    return;
  }

  final summary = describeMoveMembers(
    count: members.length,
    areDeleted: areDeleted,
    fromName: branch.name,
    toPath: branchPathOf(targetId, branches) ?? '',
  );
  final proceed = await confirmSubmit(
    context,
    isAdmin: true,
    summary: summary,
    slots: 0,
  );
  if (!proceed || !context.mounted) {
    return;
  }

  final payload = buildPersonBranchPayload(newBranchId: targetId);
  final drafts = [
    for (final member in members)
      RequestDraft(
        entityType: kEntityPerson,
        action: kActionUpdate,
        entityId: member.id,
        payload: payload,
      ),
  ];

  SubmitOutcome? outcome;
  try {
    outcome = await submitChanges(context, ref, drafts: drafts);
  } catch (e) {
    if (!context.mounted) {
      return;
    }
    await showErrorDialog(context, e);
    return;
  }
  if (outcome != SubmitOutcome.saved) {
    return;
  }

  // Số người theo chi đã đổi: làm mới để thẻ tự cập nhật.
  container.invalidate(branchUsageProvider);
  if (!context.mounted) {
    return;
  }
  await showSubmitDone(context, outcome);
}