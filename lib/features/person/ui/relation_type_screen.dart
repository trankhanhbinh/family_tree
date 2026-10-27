import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/core/ui/choice_dialog.dart';
import 'package:familytree/core/ui/form_widgets.dart';
import 'package:familytree/features/auth/ui/contributor_gate.dart';
import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/person/domain/relation_changes.dart';
import 'package:familytree/features/proposals/data/change_request_repository.dart';
import 'package:familytree/features/proposals/ui/proposal_placeholder_screen.dart';
import 'package:familytree/features/proposals/ui/sender_card.dart';
import 'package:familytree/features/proposals/ui/submit_bar.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';
import 'package:familytree/features/tree/domain/parent_child.dart';

/// Đổi loại quan hệ (ruột / nuôi / riêng) của một đứa trẻ với TẤT CẢ cha mẹ.
class RelationTypeScreen extends ConsumerWidget {
  const RelationTypeScreen({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(treeDataProvider);
    final data = async.value;
    final child = data?.people.where((p) => p.id == childId).firstOrNull;

    if (data == null || child == null) {
      String? message;
      if (async.hasError) {
        message = 'Không tải được dữ liệu.';
      } else if (data != null) {
        message = 'Không tìm thấy người này.';
      }
      return ProposalPlaceholderScreen(
        title: 'Đổi loại quan hệ',
        message: message,
      );
    }

    final rows =
        data.parentChildren.where((pc) => pc.childId == childId).toList();
    if (rows.isEmpty) {
      return const ProposalPlaceholderScreen(
        title: 'Đổi loại quan hệ',
        message: 'Không tìm thấy quan hệ cha mẹ - con này.',
      );
    }

    final byId = {for (final p in data.people) p.id: p};
    return _RelationTypeForm(
      child: child,
      rows: rows,
      parentNames: [for (final r in rows) ?byId[r.parentId]?.fullName],
    );
  }
}

class _RelationTypeForm extends ConsumerStatefulWidget {
  const _RelationTypeForm({
    required this.child,
    required this.rows,
    required this.parentNames,
  });

  final Person child;
  final List<ParentChild> rows;
  final List<String> parentNames;

  @override
  ConsumerState<_RelationTypeForm> createState() => _RelationTypeFormState();
}

class _RelationTypeFormState extends ConsumerState<_RelationTypeForm> {
  // Các dòng khác loại nhau thì chưa chọn sẵn (null).
  late final RelationType? _initial = widget.rows
          .every((r) => r.relationType == widget.rows.first.relationType)
      ? widget.rows.first.relationType
      : null;
  late RelationType? _selected = _initial;
  final TextEditingController _note = TextEditingController();
  late final Listenable _all = _note;
  bool _submitting = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _dirty => _selected != _initial || _note.text.trim().isNotEmpty;

  String _label(RelationType type) {
    return switch (type) {
      RelationType.biological => 'con ruột',
      RelationType.adopted => 'con nuôi',
      RelationType.step => 'con riêng',
    };
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    final selected = _selected;
    if (selected == null) {
      await showMessageDialog(
        context,
        title: 'Chưa gửi được',
        message: 'Vui lòng chọn loại quan hệ.',
        icon: Icons.error_outline,
        isError: true,
      );
      return;
    }

    final drafts = planChangeRelationType(
      childId: widget.child.id,
      parentChildren: widget.rows,
      newType: selected,
    );
    if (drafts.isEmpty) {
      await showMessageDialog(
        context,
        title: 'Bạn chưa thay đổi gì',
        message: 'Hãy chọn một loại quan hệ khác với hiện tại.',
      );
      return;
    }

    final parents = widget.parentNames.join(' và ');
    final confirmed = await showChoiceDialog(
      context,
      title: 'Gửi đề xuất này?',
      message: 'Đổi ${widget.child.fullName} thành ${_label(selected)} '
          'của $parents.\n\n'
          'Đề xuất dùng ${drafts.length} trong tối đa 10 suất chờ duyệt.',
      primaryLabel: 'Gửi đề xuất',
      secondaryLabel: 'Xem lại',
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final contributor = await ensureContributor(context, ref);
      if (contributor == null || !mounted) {
        return;
      }
      final note = _note.text.trim();
      await ref.read(changeRequestRepositoryProvider).submitAll(
            requesterId: contributor.userId,
            nickname: contributor.nickname,
            drafts: drafts,
            note: note.isEmpty ? null : note,
          );
      if (!mounted) {
        return;
      }
      await showMessageDialog(
        context,
        title: 'Đã gửi đề xuất',
        message: 'Quản trị viên sẽ xem và duyệt.\n'
            'Thay đổi chỉ áp dụng sau khi được duyệt.',
        icon: Icons.check_circle_outline,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        await showErrorDialog(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _all,
      builder: (context, _) {
        return PopScope(
          canPop: !_dirty,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) {
              return;
            }
            final leave = await confirmLeaveWithoutSending(context);
            if (leave && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            appBar: AppBar(title: const Text('Đổi loại quan hệ')),
            body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Đổi loại quan hệ cha mẹ - con của '
                            '${widget.child.fullName}'
                            '${widget.parentNames.isEmpty ? '' : '\nCha/mẹ: ${widget.parentNames.join(', ')}'}'
                            '\nThay đổi áp dụng cho tất cả các quan hệ này.',
                            style: const TextStyle(fontSize: 16, height: 1.4),
                          ),
                        ),
                        FormCard(
                          title: 'Loại quan hệ',
                          children: [
                            BigChoiceList<RelationType>(
                              options: const [
                                (RelationType.biological, 'Con ruột'),
                                (RelationType.adopted, 'Con nuôi'),
                                (RelationType.step, 'Con riêng'),
                              ],
                              selected: _selected,
                              onChanged: (value) =>
                                  setState(() => _selected = value),
                            ),
                          ],
                        ),
                        SenderCard(noteController: _note),
                      ],
                    ),
                  ),
                ),
                SubmitBar(submitting: _submitting, onPressed: _submit),
              ],
            ),
          ),
        );
      },
    );
  }
}