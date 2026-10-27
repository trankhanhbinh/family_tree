import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/core/ui/choice_dialog.dart';
import 'package:familytree/features/auth/data/admin_provider.dart';
import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/person/domain/person_edit_form.dart';
import 'package:familytree/features/person/ui/person_form_controller.dart';
import 'package:familytree/features/person/ui/person_form_fields.dart';
import 'package:familytree/features/proposals/domain/request_draft.dart';
import 'package:familytree/features/proposals/ui/proposal_placeholder_screen.dart';
import 'package:familytree/features/proposals/ui/sender_card.dart';
import 'package:familytree/features/proposals/ui/submit_bar.dart';
import 'package:familytree/features/proposals/ui/submit_changes.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';
import 'package:familytree/features/tree/domain/branch.dart';

/// Màn hình sửa thông tin một người.
/// Người thường: gửi đề xuất (4B). Admin: lưu trực tiếp (4D-2a).
class PersonEditScreen extends ConsumerWidget {
  const PersonEditScreen({super.key, required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(treeDataProvider);
    final data = async.value;
    final person = data?.people.where((p) => p.id == personId).firstOrNull;

    if (data == null || person == null) {
      String? message;
      if (async.hasError) {
        message = 'Không tải được dữ liệu.';
      } else if (data != null) {
        message = 'Không tìm thấy người này.';
      }
      return ProposalPlaceholderScreen(
        title: 'Đề xuất sửa thông tin',
        message: message,
      );
    }

    return _PersonEditForm(person: person, branches: data.branches);
  }
}

class _PersonEditForm extends ConsumerStatefulWidget {
  const _PersonEditForm({required this.person, required this.branches});

  final Person person;
  final List<Branch> branches;

  @override
  ConsumerState<_PersonEditForm> createState() => _PersonEditFormState();
}

class _PersonEditFormState extends ConsumerState<_PersonEditForm> {
  late final PersonFormController _form =
      PersonFormController(PersonFormValues.fromPerson(widget.person));
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
    final actionLabel = isAdmin ? 'Lưu thay đổi' : 'Gửi đề xuất';
    final nowYear = DateTime.now().year;

    final errors = _form.validate(nowYear: nowYear, validateGeneration: isAdmin);
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

    final payload = buildPersonUpdatePayload(
      widget.person,
      _form.collect(),
      nowYear: nowYear,
      includeGeneration: isAdmin,
    );
    if (payload.isEmpty) {
      await showMessageDialog(
        context,
        title: 'Bạn chưa thay đổi gì',
        message: 'Hãy sửa ít nhất một thông tin rồi bấm "$actionLabel".',
      );
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
            entityType: kEntityPerson,
            action: kActionUpdate,
            entityId: widget.person.id,
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
            appBar: AppBar(
              title: Text(isAdmin ? 'Sửa thông tin' : 'Đề xuất sửa thông tin'),
            ),
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
                        _intro(isAdmin),
                        PersonFormFields(
                          controller: _form,
                          branches: widget.branches,
                          showGeneration: isAdmin,
                        ),
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

  Widget _intro(bool isAdmin) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 16, height: 1.4),
          children: [
            TextSpan(
              text: isAdmin
                  ? 'Bạn đang sửa trực tiếp thông tin của '
                  : 'Bạn đang đề xuất sửa thông tin của ',
            ),
            TextSpan(
              text: widget.person.fullName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: isAdmin
                  ? '. Thay đổi được lưu và hiện trên cây ngay.'
                  : '. Thay đổi sẽ được quản trị viên xem và duyệt, '
                      'chưa áp dụng ngay.',
            ),
          ],
        ),
      ),
    );
  }
}