import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/core/ui/choice_dialog.dart';
import 'package:familytree/features/auth/data/admin_provider.dart';
import 'package:familytree/features/person/domain/relation_changes.dart';
import 'package:familytree/features/person/ui/marriage_form_fields.dart';
import 'package:familytree/features/proposals/domain/request_draft.dart';
import 'package:familytree/features/proposals/ui/proposal_placeholder_screen.dart';
import 'package:familytree/features/proposals/ui/sender_card.dart';
import 'package:familytree/features/proposals/ui/submit_bar.dart';
import 'package:familytree/features/proposals/ui/submit_changes.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';
import 'package:familytree/features/tree/domain/marriage.dart';

/// Đề xuất sửa một hôn nhân (tình trạng, ngày, ghi chú).
class MarriageEditScreen extends ConsumerWidget {
  const MarriageEditScreen({super.key, required this.marriageId});

  final String marriageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(treeDataProvider);
    final data = async.value;
    final marriage =
        data?.marriages.where((m) => m.id == marriageId).firstOrNull;

    if (data == null || marriage == null) {
      String? message;
      if (async.hasError) {
        message = 'Không tải được dữ liệu.';
      } else if (data != null) {
        message = 'Không tìm thấy hôn nhân này.';
      }
      return ProposalPlaceholderScreen(
        title: 'Sửa hôn nhân',
        message: message,
      );
    }

    final byId = {for (final p in data.people) p.id: p};
    final name1 = byId[marriage.person1Id]?.fullName ?? '?';
    final name2 = byId[marriage.person2Id]?.fullName ?? '?';
    return _MarriageEditForm(marriage: marriage, names: '$name1 và $name2');
  }
}

class _MarriageEditForm extends ConsumerStatefulWidget {
  const _MarriageEditForm({required this.marriage, required this.names});

  final Marriage marriage;
  final String names;

  @override
  ConsumerState<_MarriageEditForm> createState() => _MarriageEditFormState();
}

class _MarriageEditFormState extends ConsumerState<_MarriageEditForm> {
  late final MarriageFormController _form = MarriageFormController(
    marriageFormValuesOf(widget.marriage),
    initialNotes: widget.marriage.notes ?? '',
  );
  final TextEditingController _adminNote = TextEditingController();
  late final Listenable _all = Listenable.merge([_form, _adminNote]);
  bool _submitting = false;

  @override
  void dispose() {
    _form.dispose();
    _adminNote.dispose();
    super.dispose();
  }

  bool get _dirty => _form.isDirty || _adminNote.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    final isAdmin = ref.read(isAdminProvider);
    final nowYear = DateTime.now().year;

    final errors = _form.validate(nowYear: nowYear);
    if (errors.isNotEmpty) {
      final lines = errors.values.map((e) => '• $e').join('\n');
      await showMessageDialog(
        context,
        title: isAdmin ? 'Chưa lưu được' : 'Chưa gửi được',
        message: 'Vui lòng sửa các ô báo đỏ rồi '
            '${isAdmin ? 'lưu' : 'gửi'} lại:\n\n$lines',
        icon: Icons.error_outline,
        isError: true,
      );
      if (!mounted) {
        return;
      }
      _form.scrollToFirstError(errors);
      return;
    }

    final payload = buildMarriageUpdatePayload(
      widget.marriage,
      _form.collect(),
      notes: _form.notes.text,
      nowYear: nowYear,
    );
    if (payload.isEmpty) {
      await showMessageDialog(
        context,
        title: 'Bạn chưa thay đổi gì',
        message: 'Hãy sửa ít nhất một thông tin rồi bấm '
            '"${isAdmin ? 'Lưu thay đổi' : 'Gửi đề xuất'}".',
      );
      return;
    }

    final proceed = await confirmSubmit(
      context,
      isAdmin: isAdmin,
      summary: 'Sửa thông tin hôn nhân giữa ${widget.names}.',
      slots: 1,
    );
    if (!proceed || !mounted) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final note = _adminNote.text.trim();
      final outcome = await submitChanges(
        context,
        ref,
        drafts: [
          RequestDraft(
            entityType: kEntityMarriage,
            action: kActionUpdate,
            entityId: widget.marriage.id,
            payload: payload,
          ),
        ],
        note: (isAdmin || note.isEmpty) ? null : note,
      );
      if (outcome == SubmitOutcome.cancelled || !mounted) {
        return;
      }
      await showSubmitDone(context, outcome);
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
    final isAdmin = ref.watch(isAdminProvider);

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
            appBar: AppBar(title: const Text('Sửa hôn nhân')),
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
                            isAdmin
                                ? 'Sửa trực tiếp hôn nhân giữa ${widget.names}. '
                                    'Thay đổi được lưu và hiện trên cây ngay.'
                                : 'Sửa hôn nhân giữa ${widget.names}. '
                                    'Thay đổi sẽ được quản trị viên xem và duyệt.',
                            style: const TextStyle(fontSize: 16, height: 1.4),
                          ),
                        ),
                        MarriageFormFields(controller: _form),
                        if (!isAdmin) SenderCard(noteController: _adminNote),
                      ],
                    ),
                  ),
                ),
                SubmitBar(
                  submitting: _submitting,
                  onPressed: _submit,
                  label: isAdmin ? 'Lưu thay đổi' : 'Gửi đề xuất',
                  submittingLabel: isAdmin ? 'Đang lưu...' : 'Đang gửi...',
                  icon: isAdmin ? Icons.save : Icons.send,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}