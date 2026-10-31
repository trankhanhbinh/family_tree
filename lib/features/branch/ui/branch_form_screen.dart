import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/core/ui/form_widgets.dart';
import 'package:familytree/features/auth/data/admin_provider.dart';
import 'package:familytree/features/branch/domain/branch_changes.dart';
import 'package:familytree/features/branch/domain/branch_rules.dart';
import 'package:familytree/features/branch/domain/branch_summaries.dart';
import 'package:familytree/features/person/domain/branch_path.dart';
import 'package:familytree/features/proposals/domain/request_draft.dart';
import 'package:familytree/features/proposals/ui/submit_changes.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';
import 'package:familytree/features/tree/domain/branch.dart';

/// Thêm chi (`/admin/branches/new?parent=<id>`) hoặc đổi tên chi (`/admin/branches/:id/edit`).
class BranchFormScreen extends ConsumerWidget {
  const BranchFormScreen({super.key, this.branchId, this.parentId});

  /// Có giá trị = đang đổi tên chi này.
  final String? branchId;

  /// Chỉ dùng khi thêm chi: chi cha (null = chi gốc).
  final String? parentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final treeAsync = ref.watch(treeDataProvider);
    final tree = treeAsync.value;
    final isEdit = branchId != null;

    Widget body;
    if (!isAdmin) {
      body = const _CenterMessage('Chỉ quản trị viên mới sửa được chi/nhánh.');
    } else if (tree == null) {
      body = treeAsync.hasError
          ? _ErrorView(onRetry: () => ref.invalidate(treeDataProvider))
          : const Center(child: CircularProgressIndicator());
    } else {
      Branch? original;
      if (branchId != null) {
        for (final b in tree.branches) {
          if (b.id == branchId) {
            original = b;
            break;
          }
        }
      }
      var parentMissing = false;
      if (!isEdit && parentId != null) {
        parentMissing = !tree.branches.any((b) => b.id == parentId);
      }

      if (isEdit && original == null) {
        body = const _CenterMessage(
          'Không tìm thấy chi này (có thể đã bị xóa).',
        );
      } else if (parentMissing) {
        body = const _CenterMessage(
          'Không tìm thấy chi cha (có thể đã bị xóa).',
        );
      } else {
        body = _BranchForm(
          branches: tree.branches,
          original: original,
          parentId: parentId,
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Đổi tên chi' : 'Thêm chi')),
      body: SafeArea(child: body),
    );
  }
}

class _BranchForm extends ConsumerStatefulWidget {
  const _BranchForm({
    required this.branches,
    required this.original,
    required this.parentId,
  });

  final List<Branch> branches;
  final Branch? original;
  final String? parentId;

  @override
  ConsumerState<_BranchForm> createState() => _BranchFormState();
}

class _BranchFormState extends ConsumerState<_BranchForm> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  String? _nameError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.original?.name ?? '');
    _description = TextEditingController(
      text: widget.original?.description ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final original = widget.original;
    final branches = widget.branches;
    final parentBranchId = original != null
        ? original.parentBranchId
        : widget.parentId;

    final nameError = validateBranchNameUnique(
      branches: branches,
      parentBranchId: parentBranchId,
      name: _name.text,
      excludeBranchId: original?.id,
    );
    if (nameError != null) {
      setState(() => _nameError = nameError);
      return;
    }

    final String summary;
    final RequestDraft draft;
    if (original == null) {
      final payload = buildBranchCreatePayload(
        name: _name.text,
        description: _description.text,
        parentBranchId: parentBranchId,
        sortOrder: nextSortOrder(
          branches: branches,
          parentBranchId: parentBranchId,
        ),
      );
      summary = describeBranchCreate(
        name: _name.text,
        parentPath: branchPathOf(parentBranchId, branches),
      );
      draft = RequestDraft(
        entityType: kEntityBranch,
        action: kActionCreate,
        payload: payload,
      );
    } else {
      final payload = buildBranchRenamePayload(
        original: original,
        name: _name.text,
        description: _description.text,
      );
      if (payload.isEmpty) {
        await showMessageDialog(
          context,
          title: 'Chưa có thay đổi nào',
          message: 'Bạn chưa sửa gì nên không cần lưu.',
        );
        return;
      }
      summary = describeBranchRename(
        original: original,
        payload: payload,
      ).join('\n');
      draft = RequestDraft(
        entityType: kEntityBranch,
        action: kActionUpdate,
        entityId: original.id,
        payload: payload,
      );
    }

    final proceed = await confirmSubmit(
      context,
      isAdmin: true,
      summary: summary,
      slots: 0,
    );
    if (!proceed || !mounted) {
      return;
    }

    setState(() => _saving = true);
    SubmitOutcome? outcome;
    Object? error;
    try {
      outcome = await submitChanges(context, ref, drafts: [draft]);
    } catch (e) {
      error = e;
    }
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);

    if (error != null) {
      await showErrorDialog(context, error);
      return;
    }
    if (outcome != SubmitOutcome.saved) {
      return;
    }

    await showSubmitDone(context, outcome!);
    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final original = widget.original;
    final scheme = Theme.of(context).colorScheme;
    final String locationText;
    if (original == null) {
      final path = branchPathOf(widget.parentId, widget.branches);
      locationText = 'Thuộc: ${path ?? 'Chi gốc (không thuộc chi nào)'}';
    } else {
      final path = branchPathOf(original.id, widget.branches);
      locationText = 'Vị trí hiện tại: ${path ?? original.name}';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              locationText,
              style: TextStyle(
                fontSize: 16,
                height: 1.4,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          FormCard(
            title: 'Thông tin chi',
            children: [
              AppTextField(
                controller: _name,
                label: 'Tên chi',
                maxLength: kBranchNameMaxLength,
                errorText: _nameError,
                capitalization: TextCapitalization.words,
                onChanged: () {
                  if (_nameError != null) {
                    setState(() => _nameError = null);
                  }
                },
              ),
              AppTextField(
                controller: _description,
                label: 'Mô tả (không bắt buộc)',
                maxLength: kBranchDescriptionMaxLength,
                minLines: 2,
                maxLines: 5,
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(
                _saving ? 'Đang lưu...' : 'Lưu thay đổi',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(height: 16),
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